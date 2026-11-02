# FlexFusion Stage 2 — Indian Food Reference Strategy

## Objective

Build the V1 built-in food catalogue using Indian food-composition references wherever possible. USDA matching/import work is paused and is not part of this stage.

The catalogue target remains approximately 350 useful foods, but accuracy, traceability and lawful reuse take priority over reaching a fixed count.

## Research findings (reviewed 2 November 2026)

### 1. ICMR–NIN Indian Food Composition Tables 2017 (IFCT)

- Official reference: Longvah et al. (2017), National Institute of Nutrition, ICMR.
- Covers 528 key foods and 151 food components.
- The publication states that, except for eggs, its food component data are for raw foods. Cooked values must not be inferred from raw values without a documented recipe/yield method.
- Copyright notice permits reproduction for personal use with acknowledgment, but says electronic storage or reproduction for creating a product requires prior written permission from NIN.
- Decision: use IFCT as the scientific reference for research and validation. Do not copy its tables into the app, a shipped database, or a redistributed electronic catalogue unless written permission is obtained.

Official reference: https://www.nin.res.in/ebooks/IFCT2017_16122024.pdf

### 2. Indian Nutrient Databank (INDB), Anuvaad Solutions

- Portal: https://www.anuvaad.org.in/indian-nutrient-databank/
- The portal describes 1,014 common Indian recipes with nutrient values per 100 g and per serving.
- The associated 2024 research paper describes a database of 1,095 individual food items and 1,014 recipes. Ingredient data were primarily drawn from IFCT 2017, with gaps filled using IFCT 2004, UK CoFID and USDA FoodData Central.
- The portal provides a downloadable workbook.
- The portal calls INDB open-access, but the portal page reviewed does not clearly state the dataset's reuse/redistribution licence.
- Decision: first candidate dataset for Indian recipes and a useful source for ingredient candidates. Before copying data into FlexFusion or shipping it, obtain written confirmation of the applicable licence and whether commercial app redistribution and derivative use are permitted. Record the exact version and attribution requirements.

Research paper: https://pmc.ncbi.nlm.nih.gov/articles/PMC11277795/

### 3. KABO Indian Nutrition Index

- Published page: https://kabo.co.in/pages/mcp
- The provider describes a CC BY 4.0 Indian nutrition dataset with 59 foods and 674 nutrient values, sourced from ICMR-NIN references.
- The published coverage is too small to serve as the primary 350-food catalogue.
- Decision: supplementary cross-check only after verifying the downloadable dataset, licence text, source-level attribution and data completeness. Do not treat a provider's summary as a substitute for inspecting the actual dataset.

## Stage 2 source policy

1. Prefer Indian analytical data for individual foods, especially IFCT, subject to permission for product use.
2. Evaluate INDB as the leading candidate for Indian recipes and potential ingredient records, subject to explicit reuse rights.
3. Use KABO only as a small supplementary source after licence and data verification.
4. Where no suitable licensed Indian value exists, create a documented recipe estimate from ingredients whose data can lawfully be used. Label it as an estimate and retain ingredient quantities, cooking yield and final edible weight.
5. Do not silently substitute an unrelated food, foreign variety, raw/cooked state or branded product.
6. Do not invent nutrient values to fill catalogue gaps. Leave unsupported foods pending or omit them from the initial release.

## Required record metadata

Every production food record must retain:
- stable FlexFusion food ID;
- display name, aliases and category;
- preparation state and edible portion;
- base unit and nutrition basis (per 100 g or per 100 ml);
- energy (kcal), protein, carbohydrate and total fat;
- source organisation, source title/version and source record/page/table;
- source licence/permission reference and required attribution;
- verification status and review notes.

For recipe-derived dishes, additionally retain the ingredient list, ingredient quantities, source food IDs, cooking method, raw and final cooked weights/yield, serving definition and calculation date.

## Quality gates before catalogue seeding

- Source licence or written permission is documented for every copied or derived dataset.
- Each food's identity, variety, preparation state and edible portion match its source.
- Required macronutrients and energy have a traceable basis and units.
- Raw and cooked foods are distinct where composition differs.
- Recipe calculations use measured/documented ingredient quantities and final yield.
- Duplicate names and synonyms are handled without creating duplicate foods.
- Missing or uncertain values remain pending review.
- Seed process is idempotent and does not overwrite custom foods.
- Tests cover source metadata, valid units, nutrition scaling, uniqueness and repeat seeding.

## Immediate work sequence

1. Obtain and inspect the INDB workbook and its data dictionary.
2. Request written confirmation from Anuvaad about commercial app use, redistribution, derivative databases and attribution.
3. Request written permission from ICMR–NIN if FlexFusion needs to store IFCT values electronically in a shipped product.
4. Inspect KABO's actual dataset and licence text before considering any import.
5. Build a source-to-food coverage matrix for the existing 350-food plan. Do not write nutrition values into the production manifest until each source has passed the licence and quality gates.
6. Prepare a small reviewed pilot batch, then add the idempotent SQLite catalogue seed and tests.

## Explicitly out of scope for this stage

- USDA candidate matching/import scripts and USDA datasets.
- Automatic fuzzy matching as an approval mechanism.
- Bulk copying IFCT values without written permission.
- Importing unverified recipe estimates as exact laboratory values.
- Branded packaged-food lookup; this remains a separate later stage.
