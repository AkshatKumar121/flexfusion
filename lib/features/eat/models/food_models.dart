/// Shared food catalogue and logged-food value objects used by nutrition flows.

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

const fallbackFoods = <FoodData>[
  FoodData('Chicken breast, raw', 120, 22.5, 0, 2.6),
  FoodData('Egg, whole', 143, 12.6, .7, 9.5),
  FoodData('Paneer', 265, 18.3, 1.2, 20.8),
  FoodData('Cooked white rice', 130, 2.7, 28.2, .3),
  FoodData('Roti, whole wheat', 297, 9.8, 55.9, 3.7),
  FoodData('Oats, dry', 389, 16.9, 66.3, 6.9),
  FoodData('Banana', 89, 1.1, 22.8, .3),
  FoodData('Apple', 52, .3, 13.8, .2),
  FoodData('Plain curd', 61, 3.5, 4.7, 3.3),
  FoodData('Milk, toned', 60, 3, 4.8, 3),
  FoodData('Almonds', 579, 21.2, 21.6, 49.9),
  FoodData('Boiled potato', 87, 1.9, 20.1, .1),
  FoodData('Moong dal, cooked', 105, 7, 19.2, .4),
  FoodData('Besan', 387, 22.4, 57.8, 6.7),
];
