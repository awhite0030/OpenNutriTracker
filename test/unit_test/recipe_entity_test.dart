import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

void main() {
  group('RecipeEntity', () {
    test('toMealEntity copies imagePath to localImagePath', () {
      final recipe = RecipeEntity(
        id: '123',
        name: 'Test Recipe',
        description: null,
        ingredients: const [],
        totalWeightG: 100,
        aggregatedNutrimentsPer100: MealNutrimentsEntity.empty(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        servingsCount: null,
        imagePath: 'recipe_images/123.webp',
      );

      final meal = recipe.toMealEntity();

      expect(meal.localImagePath, 'recipe_images/123.webp');
      expect(meal.source, MealSourceEntity.recipe);
    });
  });
}
