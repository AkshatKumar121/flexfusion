#!/usr/bin/env python3
"""Build conservative USDA SR Legacy candidates for FlexFusion catalogue batch 1.

Unlike fuzzy matching, this uses curated USDA description phrases. It never
selects a merely similar food (for example, okra for dal). Unavailable foods
are explicitly marked NO_SAFE_MATCH. Output is a review file only; the app's
production catalogue is never modified.
"""
from __future__ import annotations

import csv
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "development_data" / "FoodData_Central_sr_legacy_food_csv_2018-04"
MANIFEST = ROOT / "assets" / "data" / "food_catalogue_manifest.csv"
OUTPUT = ROOT / "development_data" / "batch1_usda_candidates.csv"
NUTRIENTS = {"1003": "protein", "1004": "fat", "1005": "carbs", "1008": "kcal"}

# Each phrase is a deliberate USDA-description match, not a fuzzy synonym.
# "proxy" means the source food is related but is NOT the exact Indian food.
# Exclude descriptions that contain a phrase but are clearly a prepared product,
# syrup, bread, or otherwise unsuitable ingredient match.
EXCLUDE_TERMS: dict[str, tuple[str, ...]] = {
    "FF017": ("tortilla", "bread", "rolls", "cake", "mix"),
    "FF018": ("rolls", "bread", "hamburger", "hot dog"),
    "FF019": ("rolls", "bread", "hamburger", "hot dog"),
    "FF024": ("syrup", "syrups", "rolls", "bread"),
    "FF025": ("syrup", "syrups", "rolls", "bread"),
    "FF034": ("mix", "tortilla", "chips", "bread"),
}

MAX_CANDIDATES_PER_FOOD = 5

ALIASES: dict[str, tuple[str, list[str]]] = {
    "FF001": ("direct", ["rice white medium grain raw", "rice white long grain raw", "rice white short grain raw"]),
    "FF002": ("direct", ["rice white medium grain cooked", "rice white long grain cooked", "rice white short grain cooked"]),
    "FF003": ("direct", ["rice brown raw"]),
    "FF004": ("direct", ["rice brown cooked"]),
    "FF005": ("proxy", ["rice white long grain raw"]),  # USDA SR Legacy does not reliably identify basmati.
    "FF006": ("proxy", ["rice white long grain cooked"]),
    "FF007": ("direct", ["rice white long grain parboiled raw", "rice white parboiled raw"]),
    "FF008": ("direct", ["rice white long grain parboiled cooked", "rice white parboiled cooked"]),
    "FF009": ("proxy", ["rice red raw"]),  # only exact red-rice descriptions qualify; otherwise no match.
    "FF010": ("proxy", ["rice red cooked"]),
    "FF011": ("proxy", ["rice flakes dry"]),  # poha may not be explicitly represented.
    "FF012": ("proxy", ["rice flakes cooked"]),
    "FF013": ("direct", ["rice puffed"]),
    "FF014": ("proxy", ["rice flakes"]),
    "FF015": ("direct", ["wheat hard red winter"]),
    "FF016": ("direct", ["wheat flour whole grain", "wheat flour whole wheat"]),
    "FF017": ("proxy", ["wheat flour all purpose", "wheat flour white"]),
    "FF018": ("proxy", ["wheat cracked"]),
    "FF019": ("proxy", ["wheat cracked cooked"]),
    "FF020": ("direct", ["oats regular dry", "oats rolled dry", "oats quick dry"]),
    "FF021": ("direct", ["oatmeal cooked"]),
    "FF022": ("proxy", ["millet flour"]),
    "FF023": ("proxy", ["millet cooked"]),
    "FF024": ("proxy", ["sorghum flour", "sorghum"]),
    "FF025": ("proxy", ["sorghum cooked"]),
    "FF026": ("proxy", ["pearl millet flour", "millet flour"]),
    "FF027": ("proxy", ["pearl millet cooked", "millet cooked"]),
    "FF028": ("direct", ["barley pearled raw", "barley hulled raw"]),
    "FF029": ("direct", ["barley pearled cooked", "barley hulled cooked"]),
    "FF030": ("direct", ["quinoa uncooked", "quinoa raw"]),
    "FF031": ("direct", ["quinoa cooked"]),
    "FF032": ("direct", ["corn sweet yellow raw", "corn sweet white raw"]),
    "FF033": ("direct", ["corn sweet yellow cooked boiled", "corn sweet white cooked boiled"]),
    "FF034": ("proxy", ["corn flour whole grain", "cornmeal whole grain"]),
    "FF035": ("direct", ["semolina unenriched", "semolina enriched"]),
    "FF036": ("direct", ["tapioca pearl dry", "tapioca pearls dry"]),
    "FF037": ("proxy", ["tapioca cooked"]),
    "FF038": ("proxy", ["pigeon peas raw", "pigeon peas mature seeds raw"]),
    "FF039": ("proxy", ["pigeon peas cooked"]),
    "FF040": ("proxy", ["mung beans mature seeds raw", "mung beans raw"]),
    "FF041": ("proxy", ["mung beans cooked"]),
    "FF042": ("direct", ["mung beans mature seeds raw", "mung beans raw"]),
    "FF043": ("direct", ["mung beans cooked"]),
    "FF044": ("direct", ["lentils raw"]),
    "FF045": ("direct", ["lentils cooked"]),
    "FF046": ("proxy", ["black gram raw", "urad"]),
    "FF047": ("proxy", ["black gram cooked", "urad cooked"]),
    "FF048": ("proxy", ["chickpeas mature seeds raw", "chickpeas raw"]),
    "FF049": ("proxy", ["chickpeas cooked"]),
    "FF050": ("proxy", ["chickpeas brown raw", "chickpeas mature seeds raw"]),
}


def norm(value: str) -> str:
    value = value.lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return " ".join(value.split())


def main() -> None:
    for filename in ("food.csv", "food_nutrient.csv"):
        if not (DATA / filename).exists():
            raise SystemExit(f"Missing required file: {DATA / filename}")

    foods: list[tuple[str, str, str]] = []
    with (DATA / "food.csv").open(newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            description = row["description"]
            foods.append((row["fdc_id"], description, norm(description)))

    nutrient_values: dict[str, dict[str, str]] = defaultdict(dict)
    with (DATA / "food_nutrient.csv").open(newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            name = NUTRIENTS.get(row["nutrient_id"])
            amount = row.get("amount", "").strip()
            if name and amount:
                nutrient_values[row["fdc_id"]][name] = amount

    with MANIFEST.open(newline="", encoding="utf-8-sig") as f:
        batch = list(csv.DictReader(f))[:50]

    output_rows = []
    for item in batch:
        catalogue_id = item["catalogue_id"]
        match_type, phrases = ALIASES.get(catalogue_id, ("none", []))
        matches: dict[str, tuple[str, str, int]] = {}
        excluded = tuple(norm(term) for term in EXCLUDE_TERMS.get(catalogue_id, ()))
        for phrase_priority, phrase in enumerate(phrases):
            needle = norm(phrase)
            for fdc_id, description, normalized in foods:
                if needle not in normalized:
                    continue
                if any(term in normalized for term in excluded):
                    continue
                # Prefer the first, most specific curated phrase. Keep the
                # original USDA description visible for human review.
                previous = matches.get(fdc_id)
                if previous is None or phrase_priority < previous[2]:
                    matches[fdc_id] = (description, phrase, phrase_priority)

        if not matches:
            output_rows.append({
                "catalogue_id": catalogue_id,
                "catalogue_name": item["display_name"],
                "candidate_rank": "",
                "match_type": "none",
                "matched_alias": "",
                "fdc_id": "",
                "usda_description": "",
                "kcal_per_100g": "",
                "protein_g_per_100g": "",
                "carbs_g_per_100g": "",
                "fat_g_per_100g": "",
                "review_status": "NO_SAFE_MATCH",
            })
            continue

        ranked = sorted(
            matches.items(),
            key=lambda pair: (pair[1][2], len(norm(pair[1][0])), pair[0]),
        )[:MAX_CANDIDATES_PER_FOOD]
        for rank, (fdc_id, (description, phrase, _priority)) in enumerate(ranked, 1):
            values = nutrient_values.get(fdc_id, {})
            output_rows.append({
                "catalogue_id": catalogue_id,
                "catalogue_name": item["display_name"],
                "candidate_rank": rank,
                "match_type": match_type,
                "matched_alias": phrase,
                "fdc_id": fdc_id,
                "usda_description": description,
                "kcal_per_100g": values.get("kcal", ""),
                "protein_g_per_100g": values.get("protein", ""),
                "carbs_g_per_100g": values.get("carbs", ""),
                "fat_g_per_100g": values.get("fat", ""),
                "review_status": "REVIEW_REQUIRED",
            })

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "catalogue_id", "catalogue_name", "candidate_rank", "match_type",
        "matched_alias", "fdc_id", "usda_description", "kcal_per_100g",
        "protein_g_per_100g", "carbs_g_per_100g", "fat_g_per_100g",
        "review_status",
    ]
    with OUTPUT.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(output_rows)

    safe = sum(row["review_status"] == "REVIEW_REQUIRED" for row in output_rows)
    missing = sum(row["review_status"] == "NO_SAFE_MATCH" for row in output_rows)
    print(f"Created: {OUTPUT}")
    print(f"Candidate rows: {safe}; catalogue foods with no safe phrase match: {missing}")
    print(f"Candidates are capped at {MAX_CANDIDATES_PER_FOOD} per food; unsuitable prepared-product matches are excluded.")
    print("DIRECT and PROXY matches both require human review; PROXY is not an exact food match.")
    print("No production catalogue values were changed.")


if __name__ == "__main__":
    main()
