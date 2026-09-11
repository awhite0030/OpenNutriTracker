import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_bottom_sheet.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockMealDetailBloc extends Mock implements MealDetailBloc {}

void main() {
  Widget createWidgetUnderTest(MealEntity meal, String initialQuantity, String initialUnit) {
    final controller = TextEditingController(text: initialQuantity);
    final bloc = MockMealDetailBloc();

    return MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale("en", "")],
      home: Scaffold(
        body: MealDetailBottomSheet(
          product: meal,
          day: DateTime.now(),
          intakeTypeEntity: IntakeTypeEntity.lunch,
          quantityTextController: controller,
          mealDetailBloc: bloc,
          selectedUnit: initialUnit,
          onQuantityOrUnitChanged: (q, u) {},
        ),
      ),
    );
  }

  MealEntity createMeal({double? servingQuantity, String? servingUnit, String? servingSize, String? mealUnit}) {
    return MealEntity(
      code: 'test',
      name: 'Test product',
      url: null,
      mealQuantity: null,
      mealUnit: mealUnit,
      servingQuantity: servingQuantity,
      servingUnit: servingUnit,
      servingSize: servingSize,
      nutriments: const MealNutrimentsEntity(
        energyKcal100: 100,
        carbohydrates100: 10,
        fat100: 5,
        proteins100: 5,
        sugars100: 2,
        saturatedFat100: 1,
        fiber100: 1,
      ),
      source: MealSourceEntity.off,
    );
  }

  group('MealDetailBottomSheet Quick Select Chips', () {
    testWidgets('Shows 0.5x, 1x, 2x chips when scalableServingQuantity is not null', (tester) async {
      final meal = createMeal(servingQuantity: 100, servingUnit: 'g', mealUnit: 'g');

      await tester.pumpWidget(createWidgetUnderTest(meal, '1', UnitDropdownItem.serving.toString()));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-0.5x'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-1x'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-2x'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-100g'),
        findsOneWidget,
      ); // Assuming metric and solid
    });

    testWidgets('Does not show 0.5x, 1x, 2x chips when scalableServingQuantity is null', (tester) async {
      final meal = createMeal(mealUnit: 'g');

      await tester.pumpWidget(createWidgetUnderTest(meal, '100', UnitDropdownItem.g.toString()));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-0.5x'),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-1x'),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-2x'),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-100g'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping 0.5x chip updates the controller', (tester) async {
      final meal = createMeal(servingQuantity: 100, servingUnit: 'g', mealUnit: 'g');

      final controller = TextEditingController(text: '1');
      final bloc = MockMealDetailBloc();

      String? updatedQ;
      String? updatedU;

      final widget = MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale("en", "")],
        home: Scaffold(
          body: MealDetailBottomSheet(
            product: meal,
            day: DateTime.now(),
            intakeTypeEntity: IntakeTypeEntity.lunch,
            quantityTextController: controller,
            mealDetailBloc: bloc,
            selectedUnit: UnitDropdownItem.serving.toString(),
            onQuantityOrUnitChanged: (q, u) {
              updatedQ = q;
              updatedU = u;
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'quick-select-0.5x'));
      await tester.pump();

      expect(controller.text, '0.5');
      expect(updatedQ, '0.5');
      expect(updatedU, UnitDropdownItem.serving.toString());
    });
  });
}
