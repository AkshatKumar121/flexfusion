# Food catalogue

The built-in food catalogue is intentionally empty in this version.

Use **Eat → Add Food → Custom Food** to enter foods manually. Custom foods are
saved locally in SQLite and can be reused in future meal logs.

The old imported catalogue asset is no longer bundled or seeded. On the first
database open after this update, existing built-in food rows are cleared once.
Custom foods and historical meal logs are preserved; historical log snapshots
remain readable even when their old food reference is cleared.
