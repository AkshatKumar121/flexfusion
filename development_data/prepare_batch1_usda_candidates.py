#!/usr/bin/env python3
"""Prepare review candidates for FlexFusion catalogue batch 1 from USDA SR Legacy.

This script does not modify the production catalogue. It writes a review CSV with
the closest USDA food descriptions and available kcal/protein/carbs/fat values.
All candidates require human verification before being copied into the app.
"""
from __future__ import annotations

import csv
import difflib
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "development_data" / "FoodData_Central_sr_legacy_food_csv_2018-04"
MANIFEST = ROOT / "assets" / "data" / "food_catalogue_manifest.csv"
OUTPUT = ROOT / "development_data" / "batch1_usda_candidates.csv"
NUTRIENTS = {"1003": "protein", "1004": "fat", "1005": "carbs", "1008": "kcal"}


def norm(value: str) -> str:
    value = value.lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return " ".join(value.split())


def score(query: str, candidate: str) -> float:
    q, c = norm(query), norm(candidate)
    if q == c:
        return 1.0
    qt, ct = set(q.split()), set(c.split())
    overlap = len(qt & ct) / max(1, len(qt | ct))
    seq = difflib.SequenceMatcher(None, q, c).ratio()
    return 0.65 * overlap + 0.35 * seq


def main() -> None:
    for filename in ("food.csv", "food_nutrient.csv", "nutrient.csv"):
        if not (DATA / filename).exists():
            raise SystemExit(f"Missing required file: {DATA / filename}")

    foods = []
    with (DATA / "food.csv").open(newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            foods.append((row["fdc_id"], row["description"]))

    nutrient_values: dict[str, dict[str, str]] = defaultdict(dict)
    with (DATA / "food_nutrient.csv").open(newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            key = row["nutrient_id"]
            if key in NUTRIENTS and row.get("amount", "").strip():
                nutrient_values[row["fdc_id"]][NUTRIENTS[key]] = row["amount"]

    with MANIFEST.open(newline="", encoding="utf-8-sig") as f:
        batch = list(csv.DictReader(f))[:50]

    output_rows = []
    for item in batch:
        ranked = sorted(
            ((score(item["display_name"], description), fdc_id, description)
             for fdc_id, description in foods),
            reverse=True,
        )[:5]
        for rank, (similarity, fdc_id, description) in enumerate(ranked, 1):
            values = nutrient_values.get(fdc_id, {})
            output_rows.append({
                "catalogue_id": item["catalogue_id"],
                "catalogue_name": item["display_name"],
                "candidate_rank": rank,
                "match_score": f"{similarity:.3f}",
                "fdc_id": fdc_id,
                "usda_description": description,
                "kcal_per_100g": values.get("kcal", ""),
                "protein_g_per_100g": values.get("protein", ""),
                "carbs_g_per_100g": values.get("carbs", ""),
                "fat_g_per_100g": values.get("fat", ""),
                "review_status": "REVIEW_REQUIRED",
            })

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(output_rows[0]))
        writer.writeheader()
        writer.writerows(output_rows)
    print(f"Created: {OUTPUT}")
    print(f"Rows: {len(output_rows)} (5 candidates x {len(batch)} catalogue foods)")
    print("No production catalogue values were changed.")


if __name__ == "__main__":
    main()
