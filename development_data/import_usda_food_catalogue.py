#!/usr/bin/env python3
"""Build review-only food candidates from USDA FoodData Central CSV exports.

Supports extracted Foundation Foods and SR Legacy folders. It reads the
manifest, food, food_nutrient and nutrient tables and writes a candidate CSV.
It NEVER edits the production manifest or SQLite database and NEVER marks a
candidate as approved automatically.

Usage:
  python3 development_data/import_usda_food_catalogue.py \
    --source-dir development_data/FoodData_Central_sr_legacy_food_csv_2018-04

For Foundation Foods, point --source-dir at the extracted October 2026 folder.
"""
from __future__ import annotations

import argparse
import csv
import re
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "assets/data/food_catalogue_manifest.csv"
DEFAULT_OUTPUT = ROOT / "development_data/usda_catalogue_candidates.csv"

# Explicit aliases improve recall without treating a fuzzy name as verified.
ALIASES = {
    "rice": ("rice",),
    "white rice": ("rice white",),
    "brown rice": ("rice brown",),
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
    "makai": ("corn flour", "maize flour"),
    "sooji": ("semolina",),
    "sabudana": ("tapioca pearl",),
    "toor dal": ("pigeon peas", "red gram"),
    "moong": ("mung beans", "mung bean"),
    "masoor": ("lentils",),
    "urad": ("black gram", "urad"),
    "chana": ("chickpeas", "bengal gram"),
}

STATE_TERMS = {
    "raw": ("raw", "uncooked"),
    "cooked": ("cooked",),
    "boiled": ("boiled",),
    "dry": ("dry",),
}
GENERIC = {
    "food", "foods", "raw", "cooked", "dry", "boiled", "fresh",
    "whole", "medium", "large", "small", "plain", "unspecified",
}


def norm(value: str) -> str:
    value = value.lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return " ".join(value.split())


def tokens(value: str) -> set[str]:
    return {t for t in norm(value).split() if t not in GENERIC and len(t) > 1}


def find_table(folder: Path, filename: str) -> Path:
    matches = list(folder.rglob(filename))
    if not matches:
        raise SystemExit(f"Could not find {filename} under {folder}")
    if len(matches) > 1:
        # Prefer a table at the selected source root, otherwise fail clearly.
        root_match = [p for p in matches if p.parent == folder]
        if len(root_match) == 1:
            return root_match[0]
        raise SystemExit(
            f"Found multiple {filename} files. Pass --source-dir for one "
            "specific USDA dataset folder."
        )
    return matches[0]


def field(row: dict[str, str], *names: str) -> str:
    for name in names:
        value = row.get(name)
        if value is not None and str(value).strip():
            return str(value).strip()
    return ""


def load_nutrient_ids(path: Path) -> dict[str, str]:
    """Map USDA nutrient IDs to our four canonical macros using names/units."""
    mapping: dict[str, str] = {}
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            nutrient_id = field(row, "id", "nutrient_id")
            name = norm(field(row, "name", "nutrient_name"))
            unit = norm(field(row, "unit_name", "unit"))
            if not nutrient_id:
                continue
            if "protein" in name and unit == "g":
                mapping[nutrient_id] = "protein"
            elif ("total lipid" in name or name == "fat") and unit == "g":
                mapping[nutrient_id] = "fat"
            elif "carbohydrate" in name and "by difference" in name and unit == "g":
                mapping[nutrient_id] = "carbs"
            elif name == "energy" and unit in {"kcal", "kcal"}:
                mapping[nutrient_id] = "kcal"
    # SR Legacy fallback for the canonical nutrient IDs when a supporting
    # nutrient.csv is absent or uses a different naming convention.
    mapping.setdefault("1003", "protein")
    mapping.setdefault("1004", "fat")
    mapping.setdefault("1005", "carbs")
    mapping.setdefault("1008", "kcal")
    return mapping


def load_foods(food_path: Path) -> dict[str, dict[str, str]]:
    foods = {}
    with food_path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            fdc_id = field(row, "fdc_id")
            description = field(row, "description", "name")
            if fdc_id and description:
                foods[fdc_id] = {
                    "description": description,
                    "data_type": field(row, "data_type") or "USDA dataset",
                    "normalized": norm(description),
                }
    return foods


def load_nutrients(path: Path, nutrient_map: dict[str, str]) -> dict[str, dict[str, str]]:
    values: dict[str, dict[str, str]] = defaultdict(dict)
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            fdc_id = field(row, "fdc_id")
            nutrient_id = field(row, "nutrient_id")
            amount = field(row, "amount")
            macro = nutrient_map.get(nutrient_id)
            if fdc_id and macro and amount:
                # Keep the first matching nutrient row; duplicate nutrient
                # records are not silently averaged.
                values[fdc_id].setdefault(macro, amount)
    return values


def match_score(food_name: str, description: str, preparation: str) -> tuple[float, str]:
    name_tokens = tokens(food_name)
    desc_tokens = tokens(description)
    if not name_tokens or not desc_tokens:
        return 0.0, "insufficient name tokens"

    overlap = len(name_tokens & desc_tokens)
    coverage = overlap / len(name_tokens)
    jaccard = overlap / len(name_tokens | desc_tokens)
    ratio = SequenceMatcher(None, norm(food_name), norm(description)).ratio()
    score = 0.62 * coverage + 0.23 * jaccard + 0.15 * ratio

    # Add known Indian/common-language synonyms as candidate search phrases.
    for key, phrases in ALIASES.items():
        if key in norm(food_name):
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True,
                        help="One extracted USDA dataset folder (Foundation or SR Legacy).")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=5,
                        help="Maximum candidates per catalogue food (default: 5).")
    parser.add_argument("--minimum-score", type=float, default=0.18,
                        help="Minimum candidate score; all matches still require review.")
    args = parser.parse_args()

    food_path = find_table(args.source_dir, "food.csv")
    nutrient_path = find_table(args.source_dir, "food_nutrient.csv")
    nutrient_def_path = find_table(args.source_dir, "nutrient.csv")
    nutrient_map = load_nutrient_ids(nutrient_def_path)
    foods = load_foods(food_path)
    nutrients = load_nutrients(nutrient_path, nutrient_map)

    with args.manifest.open(newline="", encoding="utf-8-sig") as handle:
        manifest = list(csv.DictReader(handle))

    output = []
    for item in manifest:
        catalogue_id = item["catalogue_id"]
        name = item["display_name"]
        preparation = item.get("preparation_state", "unspecified")
        candidates = []
        for fdc_id, food in foods.items():
            score, reason = match_score(name, food["description"], preparation)
            if score < args.minimum_score:
                continue
            candidates.append((score, fdc_id, food, reason))

        candidates.sort(key=lambda entry: (-entry[0], entry[2]["description"]))
        for rank, (score, fdc_id, food, reason) in enumerate(candidates[:args.limit], 1):
            macro = nutrients.get(fdc_id, {})
            output.append({
                "catalogue_id": catalogue_id,
                "catalogue_name": name,
                "preparation_state": preparation,
                "candidate_rank": rank,
                "candidate_score": f"{score:.3f}",
                "fdc_id": fdc_id,
                "usda_data_type": food["data_type"],
                "usda_description": food["description"],
                "kcal_per_100g": macro.get("kcal", ""),
                "protein_g_per_100g": macro.get("protein", ""),
                "carbs_g_per_100g": macro.get("carbs", ""),
                "fat_g_per_100g": macro.get("fat", ""),
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
                "match_explanation": "No candidate above minimum score",
                "review_status": "NEEDS_SOURCE",
            })

    args.output.parent.mkdir(parents=True, exist_ok=True)
    columns = [
        "catalogue_id", "catalogue_name", "preparation_state",
        "candidate_rank", "candidate_score", "fdc_id", "usda_data_type",
        "usda_description", "kcal_per_100g", "protein_g_per_100g",
        "carbs_g_per_100g", "fat_g_per_100g", "match_explanation",
        "review_status",
    ]
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(output)

    matched_ids = {row["catalogue_id"] for row in output if row["fdc_id"]}
    print(f"Manifest foods: {len(manifest)}")
    print(f"Foods with candidates: {len(matched_ids)}")
    print(f"Foods needing another source: {len(manifest) - len(matched_ids)}")
    print(f"Candidate rows written: {len(output)}")
    print(f"Output: {args.output}")
    print("All candidates are REVIEW_REQUIRED; production data was not changed.")


if __name__ == "__main__":
    main()
