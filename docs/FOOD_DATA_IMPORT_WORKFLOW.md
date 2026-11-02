# Food data import workflow

## Goal

Build FlexFusion's food catalogue from reusable, traceable sources rather than hand-entering hundreds of nutrient records.

## Source strategy

1. **USDA FoodData Central Foundation Foods** — preferred generic ingredient source. USDA publishes CSV and JSON downloads; the October 2026 Foundation Foods CSV is approximately 4.1 MB compressed / 35 MB extracted. USDA also retains SR Legacy (April 2018), but it is a final, non-updated dataset.
2. **Open Food Facts** — online lookup for packaged/branded products. API data is community-contributed and must be treated as potentially incomplete. The current API documentation recommends v3 for product reads; full-text search remains on legacy search endpoints. Published limits include 10 search requests/minute/IP and 15 product reads/minute/IP, so do not call it on every keystroke.
3. **Indian foods and recipes** — fill gaps only from sources whose reuse terms permit app use, or from documented recipes with ingredient weights and final cooked yield. Do not bulk-copy IFCT/NIN tables without permission.
4. **User foods and recipes** — locally stored and editable, with historical nutrition snapshots.

## Current implementation utility

Run the review-only USDA candidate generator:

```bash
python3 development_data/import_usda_food_catalogue.py \
  --source-dir development_data/FoodData_Central_sr_legacy_food_csv_2018-04
```

For a newer Foundation Foods download, extract it and pass its folder:

```bash
python3 development_data/import_usda_food_catalogue.py \
  --source-dir development_data/FoodData_Central_foundation_food_csv_2026-10
```

The output defaults to `development_data/usda_catalogue_candidates.csv`.

The importer reads `food.csv`, `food_nutrient.csv`, and `nutrient.csv`; maps nutrients by their USDA names/units (with SR Legacy ID fallbacks); compares all manifest foods; and emits up to five candidate rows per food. Candidate scores are ranking aids only.

**Safety rule:** the importer never approves a match, edits the manifest, or writes to the app database. Every candidate is marked `REVIEW_REQUIRED`; missing matches are `NEEDS_SOURCE`. Human review and source identity checks must precede production import.

## Open Food Facts integration rules

- Use a product lookup by barcode for exact packaged products.
- Search only after an explicit user action; debounce and cache results.
- Request only the fields FlexFusion needs (product name, brands, code, serving size, nutriments, quantity, and completeness/quality indicators).
- Store source, source product code, retrieval date, and licence metadata with cached records.
- Show missing or incomplete nutrition clearly; do not silently invent values.
- Review ODbL obligations before redistributing a combined database or shipping a bulk OFF catalogue. Keep OFF-sourced records identifiable.

## Production data quality gates

Before a food enters the built-in catalogue:
- food identity and preparation state must match;
- all four core values (kcal, protein, carbs, fat) must have a documented basis;
- values must be per 100 g or per 100 ml as appropriate;
- nutrient units and energy basis must be checked;
- source name, source record ID, and source licence must be retained;
- proxy foods must be labelled as proxies and never silently renamed as an exact Indian food;
- cooked dishes must use documented ingredient quantities, cooking yield, and final edible weight.

## Next stages

1. Download and extract USDA Foundation Foods October 2026.
2. Run the candidate generator on Foundation Foods and compare candidate coverage with SR Legacy.
3. Review candidates in batches; add approved records to a separate production import file.
4. Build an Open Food Facts product lookup/cache service.
5. Populate and test serving conversions and recipe calculations.
6. Import reviewed built-in foods into SQLite with idempotent seeding and migration tests.
