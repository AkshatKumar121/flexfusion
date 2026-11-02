# FlexFusion Built-in Food Catalogue Plan

## Target

- Initial target: **350 generic food entries**; acceptable release range: 300–400 after quality review.
- Audience: Indian households and gym-goers.
- Built-in catalogue must work offline.
- Branded packaged products are not part of this generic seed. They belong to the separately sourced branded-food lookup/cache stage.
- Existing custom foods remain user-owned and must not be overwritten by catalogue seeding.

## Standard nutrition basis

- Solid foods: per 100 g edible portion.
- Liquids: per 100 ml where the source reports volume-based values; retain the explicit base unit.
- Required values: energy (kcal), protein (g), carbohydrate (g), total fat (g).
- Keep values as decimals; UI may round for display.
- Record preparation state explicitly: raw, cooked, boiled, steamed, roasted, grilled, fried, baked, dried, etc.
- Do not treat raw and cooked versions as interchangeable.
- Do not assume a household serving has a universal weight. Store per-food serving conversions separately in food_servings.
- For whole-item measures, define edible-portion conversion and make the assumed size explicit (e.g. small/medium/large).
- Serving conversions are quantity conversions, not new nutrient sources. Nutrients are scaled from the base quantity.
- Retain source, source identifier/reference, verification status and review notes for each food.
- Do not force kcal to equal exactly 4P + 4C + 9F; source energy may account for fibre, organic acids, specific energy factors and rounding. Preserve source energy.

## Proposed 350-entry category allocation

| Category | Target | Coverage |
|---|---:|---|
| Rice, cereals, millets and grains | 35 | Raw and cooked rice varieties, poha, oats, wheat, ragi, jowar, bajra, quinoa and other commonly used grains |
| Pulses, dals, beans and legumes | 30 | Whole/split dals, chickpeas, rajma, chole, lobia, sprouts and cooked variants |
| Vegetables and greens | 45 | Everyday Indian vegetables, roots, gourds, leafy greens and common preparation states |
| Fruits | 30 | Common Indian and widely available fruits; edible portion |
| Milk, curd and dairy | 25 | Milk types, curd, buttermilk, paneer, cheese and other commonly eaten dairy |
| Eggs, poultry, meat and fish | 35 | Common cuts and preparation states; vegetarian catalogue remains fully usable without these |
| Nuts and seeds | 15 | Almonds, peanuts, cashews, walnuts, seeds and common edible forms |
| Flours, rotis, breads and breakfast staples | 30 | Atta, besan, rice flour, idli/dosa batter, roti, chapati, paratha and common breakfast staples |
| Common Indian cooked dishes | 50 | Home-style dal, sabzi, khichdi, pulao, sambar, rasam, chilla, upma, poha, dosa, idli and more |
| Snacks, chutneys, condiments and spreads | 25 | Common savoury snacks, chutneys, sauces, pickles and spreads; recipe/brand distinctions retained |
| Gym and high-protein staples | 30 | Generic whey powder only where supported, tofu, soya chunks, lean protein staples, egg whites, Greek/hung curd and practical gym foods |
| **Total** | **350** | |

Category counts are planning targets. Final count can shift to avoid duplicates and unsupported nutrition estimates, while staying within 300–400.

## Data sourcing and licensing rules

1. **USDA FoodData Central**: use suitable records where relevant. USDA states its FoodData Central data are public domain under CC0 1.0; retain source attribution and record the FDC identifier when available.
2. **ICMR-NIN Indian Food Composition Tables 2017**: valuable Indian reference. The publication states that electronic reproduction for creating a product requires prior written permission. Do not bulk-copy its tables into the app without that permission.
3. **Indian Nutrient Databank and other recipe datasets**: do not ingest until reuse, redistribution and derivative-database licensing terms are confirmed.
4. **Packaged foods**: use manufacturer-published nutrition labels or a licensed product-data source. Branded catalogue integration is a separate stage.
5. **Home-style dishes**: use a documented standard recipe with ingredient quantities, cooking yield and final edible weight; calculate nutrients from licensed ingredient records. Label these as recipe estimates, not laboratory analyses.
6. If a food cannot be supported by a suitable source or documented recipe, defer it rather than inventing a precise macro breakdown.

## Data quality and duplicate rules

- Use stable source_id values where a source supplies them.
- Normalise names for search, but preserve clear display names.
- Distinguish variants by preparation state, fat level, cut, edible portion or other meaningful nutrition differences.
- Do not create separate records for spelling variants or synonyms; store synonyms as search terms when supported.
- Seed process must be idempotent: rerunning it must not duplicate foods or overwrite user-created foods.
- Built-in records must be distinguishable from custom/user-entered and external records.
- Keep source references and verification status on every seeded record.
- Validate non-negative macros, plausible energy ranges, non-empty names, valid base units and serving conversions.
- Add tests for seed count, uniqueness, idempotence, source metadata, nutrition basis and serving links.

## Implementation sequence

1. Finalise source/licence manifest and food list.
2. Prepare a reviewable catalogue data file with source metadata for every record.
3. Add an idempotent SQLite seed routine and category records.
4. Add standard serving conversions for common foods.
5. Test fresh install, repeat seeding, existing user data preservation and nutrition scaling.
6. Connect the catalogue to the existing Eat search without redesigning the approved screen.
