import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_detail_nutriments_table.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => EnergyUnitProvider(usesKilojoules: false),
      child: MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('Hides micronutrients when showMicronutrients is false even if has data', (tester) async {
    final meal = const MealEntity(
      code: '1',
      name: 'Nutella',
      url: 'http://nutella',
      mealQuantity: '100',
      mealUnit: 'g',
      servingSize: '15g',
      servingQuantity: 15,
      servingUnit: 'g',
      source: MealSourceEntity.off,
      nutriments: MealNutrimentsEntity(
        energyKcal100: 500,
        carbohydrates100: 50,
        fat100: 30,
        proteins100: 5,
        sugars100: 50,
        saturatedFat100: 10,
        fiber100: 5,
        vitaminC100: 10, // has micro data
      ),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MealDetailNutrimentsTable(product: meal, usesImperialUnits: false, showMicronutrients: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Micronutrients'), findsNothing);
  });

  testWidgets('Shows micronutrients when showMicronutrients is true', (tester) async {
    final meal = const MealEntity(
      code: '1',
      name: 'Nutella',
      url: 'http://nutella',
      mealQuantity: '100',
      mealUnit: 'g',
      servingSize: '15g',
      servingQuantity: 15,
      servingUnit: 'g',
      source: MealSourceEntity.off,
      nutriments: MealNutrimentsEntity(
        energyKcal100: 500,
        carbohydrates100: 50,
        fat100: 30,
        proteins100: 5,
        sugars100: 50,
        saturatedFat100: 10,
        fiber100: 5,
        vitaminC100: 10, // has micro data
      ),
    );

    await tester.pumpWidget(
      buildTestableWidget(MealDetailNutrimentsTable(product: meal, usesImperialUnits: false, showMicronutrients: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Micronutrients'), findsOneWidget);
  });
}
