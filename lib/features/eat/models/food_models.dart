// Shared food catalogue and logged-food value objects used by nutrition flows.

class FoodData {
  final int? id;
  final String name;
  final double kcal, protein, carbs, fat;
  final bool isCustom;
  const FoodData(this.name, this.kcal, this.protein, this.carbs, this.fat,
      {this.id, this.isCustom = false});
}

class LoggedFood {
  final int? id;
  final int? foodId;
  final String name;
  final double grams, kcal, protein, carbs, fat;
  const LoggedFood(this.name, this.grams, this.kcal, this.protein, this.carbs, this.fat,
      {this.id, this.foodId});

  LoggedFood copyWith({int? id}) => LoggedFood(
    name, grams, kcal, protein, carbs, fat, id: id ?? this.id, foodId: foodId,
  );
}
