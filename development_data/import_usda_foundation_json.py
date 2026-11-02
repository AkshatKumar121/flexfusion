#!/usr/bin/env python3
"""Build review-only catalogue candidates from USDA Foundation Foods JSON.

The input must be an official FoodData Central FoundationFoods JSON export.
The script reads nested food descriptions and nutrient records, then writes
candidate matches for manual review. It never changes the production manifest
or SQLite database and never approves a candidate automatically.

Usage:
  python3 development_data/import_usda_foundation_json.py \
    --source-file development_data/FoodData_Central_foundation_food_json_2026-10-29.json
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "assets/data/food_catalogue_manifest.csv"
DEFAULT_OUTPUT = ROOT / "development_data/usda_foundation_json_candidates.csv"

ALIASES = {
    "white rice": ("rice white", "white rice"),
    "brown rice": ("rice brown", "brown rice"),
    "basmati rice": ("basmati rice", "rice long grain"),
    "parboiled rice": ("parboiled rice", "rice converted"),
    "red rice": ("red rice",),
    "poha": ("rice flakes", "flattened rice"),
    "puffed rice": ("puffed rice",),
    "atta": ("whole wheat flour", "wheat flour whole grain"),
    "maida": ("all purpose wheat flour", "wheat flour white"),
    "dalia": ("cracked wheat", "bulgur"),
    "oats": ("oats", "oatmeal"),
    "ragi": ("finger millet",),
    "jowar": ("sorghum",),
    "bajra": ("pearl millet",),
    "sooji": ("semolina",),
    "sabudana": ("tapioca pearl",),
    "toor dal": ("pigeon peas", "red gram"),
    "moong": ("mung beans", "mung bean"),
    "masoor": ("lentils",),
    "urad": ("black gram", "urad"),
    "chana": ("chickpeas", "bengal gram"),
}
GENERIC = {
    "food", "foods", "raw", "cooked", "dry", "boiled", "fresh",
    "whole", "medium", "large", "small", "plain", "unspecified",
}
STATE_TERMS = {
    "raw": ("raw", "uncooked"),
    "cooked": ("cooked",),
    "boiled": ("boiled",),
    "dry": ("dry",),
}


def norm(value: str) -> str:
    value = value.lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return " ".join(value.split())


def tokens(value: str) -> set[str]:
    return {part for part in norm(value).split()
            if part not in GENERIC and len(part) > 1}


def match_score(food_name: str, description: str,
                preparation: str) -> tuple[float, str]:
    name_tokens = tokens(food_name)
    desc_tokens = tokens(description)
    if not name_tokens or not desc_tokens:
        return 0.0, "insufficient name tokens"

    overlap = len(name_tokens & desc_tokens)
    coverage = overlap / len(name_tokens)
    jaccard = overlap / len(name_tokens | desc_tokens)
    ratio = SequenceMatcher(None, norm(food_name), norm(description)).ratio()
    score = 0.62 * coverage + 0.23 * jaccard + 0.15 * ratio

    normalized_name = norm(food_name)
    for key, phrases in ALIASES.items():
        if key in normalized_name:
            for phrase in phrases:
                phrase_tokens = tokens(phrase)
                if phrase_tokens and phrase_tokens.issubset(desc_tokens):
                    score = max(score, 0.78 + 0.02 * min(len(phrase_tokens), 3))

    state_terms = STATE_TERMS.get(norm(preparation), ())
    if state_terms:
        if any(term in norm(description).split() for term in state_terms):
            score += 0.08
        elif preparation not in {"unspecified"}:
            score -= 0.12

    return min(score, 0.99), f"{overlap}/{len(name_tokens)} name tokens overlap"


def extract_macros(food: dict) -> dict[str, str]:
    """Extract macro amounts by nutrient name and unit.

    Foundation Foods can expose multiple kcal calculations. Prefer Atwater
    General Factors, then a plain Energy record, then Atwater Specific Factors.
    kJ records are never substituted for kcal records.
    """
    result: dict[str, str] = {}
    energy_candidates: list[tuple[int, str]] = []

    for record in food.get("foodNutrients", []):
        nutrient = record.get("nutrient") or {}
        name = norm(str(nutrient.get("name", "")))
        unit = norm(str(nutrient.get("unitName", "")))
        amount = record.get("amount")
        if amount is None:
            continue

        if name.startswith("energy") and unit == "kcal":
            if "atwater general factors" in name:
                priority = 0
            elif name == "energy":
                priority = 1
            elif "atwater specific factors" in name:
                priority = 2
            else:
                priority = 3
            energy_candidates.append((priority, str(amount)))
        elif name == "protein" and unit == "g":
            result.setdefault("protein", str(amount))
        elif name == "carbohydrate by difference" and unit == "g":
            result.setdefault("carbs", str(amount))
        elif name == "total lipid fat" and unit == "g":
            result.setdefault("fat", str(amount))

    if energy_candidates:
        energy_candidates.sort(key=lambda item: item[0])
        result["kcal"] = energy_candidates[0][1]

    return result


def load_foods(source_file: Path) -> list[dict]:
    with source_file.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    foods = payload.get("FoundationFoods") if isinstance(payload, dict) else None
    if not isinstance(foods, list):
        raise SystemExit(
            "Expected a JSON object containing a FoundationFoods array."
        )

    parsed = []
    for item in foods:
        fdc_id = item.get("fdcId")
        description = item.get("description")
        if not fdc_id or not description:
            continue
        parsed.append({
            "fdc_id": str(fdc_id),
            "description": str(description),
            "data_type": str(item.get("dataType") or "Foundation"),
            "macros": extract_macros(item),
        })
    return parsed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-file", type=Path, required=True,
                        help="Foundation Foods JSON export file.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=5,
                        help="Maximum candidates per catalogue food.")
    parser.add_argument("--minimum-score", type=float, default=0.18)
    args = parser.parse_args()

    if args.limit < 1:
        raise SystemExit("--limit must be at least 1.")
    if not args.source_file.is_file():
        raise SystemExit(f"JSON source file not found: {args.source_file}")

    foods = load_foods(args.source_file)
    with args.manifest.open(newline="", encoding="utf-8-sig") as handle:
        manifest = list(csv.DictReader(handle))

    output = []
    matched_catalogue_ids = set()
    for item in manifest:
        catalogue_id = item["catalogue_id"]
        name = item["display_name"]
        preparation = item.get("preparation_state", "unspecified")
        candidates = []
        for food in foods:
            score, reason = match_score(name, food["description"], preparation)
            if score >= args.minimum_score:
                candidates.append((score, food, reason))

        candidates.sort(key=lambda entry: (-entry[0], entry[1]["description"]))
        if candidates:
            matched_catalogue_ids.add(catalogue_id)

        for rank, (score, food, reason) in enumerate(candidates[:args.limit], 1):
            macro = food["macros"]
            missing = [key for key in ("kcal", "protein", "carbs", "fat")
                       if key not in macro]
            output.append({
                "catalogue_id": catalogue_id,
                "catalogue_name": name,
                "preparation_state": preparation,
                "candidate_rank": rank,
                "candidate_score": f"{score:.3f}",
                "fdc_id": food["fdc_id"],
                "usda_data_type": food["data_type"],
                "usda_description": food["description"],
                "kcal_per_100g": macro.get("kcal", ""),
                "protein_g_per_100g": macro.get("protein", ""),
                "carbs_g_per_100g": macro.get("carbs", ""),
                "fat_g_per_100g": macro.get("fat", ""),
                "missing_macros": ";".join(missing),
                "nutrition_basis": "USDA Foundation Foods; amounts reported per 100 g",
                "source_file": args.source_file.name,
                "match_explanation": reason,
                "review_status": "REVIEW_REQUIRED",
            })

        if not candidates:
            output.append({
                "catalogue_id": catalogue_id,
                "catalogue_name": name,
                "preparation_state": preparation,
                "candidate_rank": "",
                "candidate_score": "",
                "fdc_id": "",
                "usda_data_type": "",
                "usda_description": "",
                "kcal_per_100g": "",
                "protein_g_per_100g": "",
                "carbs_g_per_100g": "",
                "fat_g_per_100g": "",
                "missing_macros": "kcal;protein;carbs;fat",
                "nutrition_basis": "USDA Foundation Foods; amounts reported per 100 g",
                "source_file": args.source_file.name,
                "match_explanation": "No candidate above minimum score",
                "review_status": "NEEDS_SOURCE",
            })

    columns = [
        "catalogue_id", "catalogue_name", "preparation_state",
        "candidate_rank", "candidate_score", "fdc_id", "usda_data_type",
        "usda_description", "kcal_per_100g", "protein_g_per_100g",
        "carbs_g_per_100g", "fat_g_per_100g", "missing_macros",
        "nutrition_basis", "source_file", "match_explanation", "review_status",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(output)

    print(f"Foundation Foods records loaded: {len(foods)}")
    print(f"Manifest foods: {len(manifest)}")
    print(f"Foods with candidates: {len(matched_catalogue_ids)}")
    print(f"Foods needing another source: {len(manifest) - len(matched_catalogue_ids)}")
    print(f"Candidate rows written: {len(output)}")
    print("All candidates require manual review; production data was not changed.")


if __name__ == "__main__":
    main()
