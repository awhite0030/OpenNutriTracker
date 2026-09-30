import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

void main() {
  group('RecipeEntity.toMealEntity', () {
    test('servingSize is null so bottom sheet can build localized fallback', () {
      final recipe = RecipeEntity(
        id: '1',
        name: 'Cake',
        description: null,
        ingredients: const [],
        totalWeightG: 400,
        aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        servingsCount: 4,
      );

      final meal = recipe.toMealEntity();

      expect(meal.servingSize, isNull);
    });

    test('servingSize is null when servingsCount is null', () {
      final recipe = RecipeEntity(
        id: '1',
        name: 'Cake',
        description: null,
        ingredients: const [],
        totalWeightG: 400,
        aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        servingsCount: null,
      );

      final meal = recipe.toMealEntity();

      expect(meal.servingSize, isNull);
    });
  });
}
