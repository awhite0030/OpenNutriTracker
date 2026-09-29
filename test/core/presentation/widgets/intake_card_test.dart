import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/intake_card.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:provider/provider.dart';
import 'package:opennutritracker/generated/l10n.dart';

void main() {
  tearDown(() {
    GetIt.instance.reset();
  });

  Widget buildCard(IntakeEntity intake) {
    return ChangeNotifierProvider<EnergyUnitProvider>(
      create: (_) => EnergyUnitProvider(),
      child: MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.supportedLocales,
        home: Scaffold(
          body: IntakeCard(key: UniqueKey(), intake: intake, firstListElement: true, usesImperialUnits: false),
        ),
      ),
    );
  }

  testWidgets('displays emoji for FDC food when thumbnailImageUrl is null', (WidgetTester tester) async {
    final intake = IntakeEntity(
      id: '1',
      unit: 'g',
      amount: 100,
      type: IntakeTypeEntity.breakfast,
      dateTime: DateTime.now(),
      meal: MealEntity(
        code: '123',
        name: 'Apple, raw',
        thumbnailImageUrl: null,
        mainImageUrl: null,
        url: null,
        mealQuantity: '100',
        mealUnit: 'g',
        servingQuantity: null,
        servingUnit: 'g',
        servingSize: '100 g',
        nutriments: const MealNutrimentsEntity(
          energyKcal100: 52,
          carbohydrates100: 14,
          fat100: 0.2,
          proteins100: 0.3,
          sugars100: 10,
          saturatedFat100: null,
          fiber100: 2.4,
        ),
        source: MealSourceEntity.fdc,
      ),
    );

    await tester.pumpWidget(buildCard(intake));
    await tester.pumpAndSettle();

    expect(find.text('🍎'), findsOneWidget);
  });
}
