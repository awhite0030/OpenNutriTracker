import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/profile_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_profiles_usecase.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/home/presentation/widgets/intake_vertical_list.dart';
import 'package:opennutritracker/features/meal_detail/presentation/bloc/meal_detail_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeMealDetailBloc extends Fake implements MealDetailBloc {}

class _FakeHomeBloc extends Fake implements HomeBloc {}

class _SingleProfileGetProfilesUsecase implements GetProfilesUsecase {
  static final _profile = ProfileEntity(
    id: 'p1',
    name: 'Me',
    createdAt: DateTime(2026, 1, 1),
    boxSuffix: '',
  );

  @override
  List<ProfileEntity> getProfiles() => [_profile];

  @override
  String get activeProfileId => 'p1';

  @override
  ProfileEntity? getActiveProfile() => _profile;
}

IntakeEntity _buildIntake({
  required double amount,
  required double kcal100,
  required double carbs100,
  required double fat100,
  required double protein100,
}) {
  return IntakeEntity(
    id: 'test-intake',
    unit: 'g',
    amount: amount,
    type: IntakeTypeEntity.breakfast,
    dateTime: DateTime(2026, 1, 1),
    meal: MealEntity(
      code: 'test-meal',
      name: 'Test Meal',
      url: null,
      mealQuantity: '100',
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: 'g',
      servingSize: '100 g',
      nutriments: MealNutrimentsEntity(
        energyKcal100: kcal100,
        carbohydrates100: carbs100,
        fat100: fat100,
        proteins100: protein100,
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
      ),
      source: MealSourceEntity.custom,
    ),
  );
}

Widget _wrapWithMaterial(Widget child, {bool useKj = false}) {
  return ChangeNotifierProvider<EnergyUnitProvider>(
    create: (_) {
      final p = EnergyUnitProvider();
      if (useKj) p.updateUsesKilojoules(true);
      return p;
    },
    child: MaterialApp(
      localizationsDelegates: const [S.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
      supportedLocales: const [Locale('en', '')],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUpAll(() {
    final locator = GetIt.instance;
    locator.registerFactory<MealDetailBloc>(_FakeMealDetailBloc.new);
    locator.registerFactory<HomeBloc>(_FakeHomeBloc.new);
    locator.registerFactory<GetProfilesUsecase>(
      _SingleProfileGetProfilesUsecase.new,
    );
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  testWidgets('displays unit correctly with a meal target in kj mode', (tester) async {
    final intakes = [
      _buildIntake(amount: 100, kcal100: 200, carbs100: 20, fat100: 10, protein100: 5),
    ];
    await tester.pumpWidget(_wrapWithMaterial(IntakeVerticalList(
      day: DateTime(2026, 1, 1),
      title: 'Breakfast',
      listIcon: Icons.bakery_dining_outlined,
      addMealType: AddMealType.breakfastType,
      intakeList: intakes,
      usesImperialUnits: false,
      showMealMacros: false,
      mealKcalTarget: 400,
      onDeleteIntakeCallback: (_, _) {},
    ), useKj: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('836 / 1673 kJ'), findsOneWidget);
  });

  testWidgets('displays unit correctly with a meal target in kcal mode', (tester) async {
    final intakes = [
      _buildIntake(amount: 100, kcal100: 200, carbs100: 20, fat100: 10, protein100: 5),
    ];
    await tester.pumpWidget(_wrapWithMaterial(IntakeVerticalList(
      day: DateTime(2026, 1, 1),
      title: 'Breakfast',
      listIcon: Icons.bakery_dining_outlined,
      addMealType: AddMealType.breakfastType,
      intakeList: intakes,
      usesImperialUnits: false,
      showMealMacros: false,
      mealKcalTarget: 400,
      onDeleteIntakeCallback: (_, _) {},
    ), useKj: false));
    await tester.pumpAndSettle();

    expect(find.textContaining('200 / 400 kcal'), findsOneWidget);
  });
}
