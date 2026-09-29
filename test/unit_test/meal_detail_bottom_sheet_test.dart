import 'package:flutter_test/flutter_test.dart';

import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

// Test mirroring the internal function of MealDetailBottomSheet
void main() {
  group('MealDetailBottomSheet _hasRequiredProductInfoMissing mirror', () {
    bool hasRequiredProductInfoMissing(MealEntity product) {
      if (product.source == MealSourceEntity.custom) {
        return false;
      }
      final productNutriments = product.nutriments;
      if (productNutriments.energyKcal100 == null ||
          productNutriments.carbohydrates100 == null ||
          productNutriments.fat100 == null ||
          productNutriments.proteins100 == null) {
        return true;
      } else {
        return false;
      }
    }

    test('returns false for custom meals missing macros', () {
      final customMeal = MealEntity(
        code: 'custom',
        name: 'Custom',
        url: null,
        mealQuantity: '100',
        mealUnit: 'gml',
        servingQuantity: null,
        servingUnit: 'gml',
        servingSize: '',
        source: MealSourceEntity.custom,
        nutriments: const MealNutrimentsEntity(
          energyKcal100: 500,
          carbohydrates100: null,
          fat100: null,
          proteins100: null,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        ),
      );

      expect(hasRequiredProductInfoMissing(customMeal), isFalse);
    });

    test('returns true for OFF meals missing macros', () {
      final offMeal = MealEntity(
        code: 'off',
        name: 'OFF',
        url: null,
        mealQuantity: '100',
        mealUnit: 'gml',
        servingQuantity: null,
        servingUnit: 'gml',
        servingSize: '',
        source: MealSourceEntity.off,
        nutriments: const MealNutrimentsEntity(
          energyKcal100: 500,
          carbohydrates100: null,
          fat100: null,
          proteins100: null,
          sugars100: null,
          saturatedFat100: null,
          fiber100: null,
        ),
      );

      expect(hasRequiredProductInfoMissing(offMeal), isTrue);
    });
  });
}
