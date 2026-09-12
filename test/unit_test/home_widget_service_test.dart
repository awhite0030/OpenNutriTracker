import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/utils/home_widget_service.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeWidgetService homeWidgetService;
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    homeWidgetService = HomeWidgetService();
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        return true;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
  });

  test('updateWidgetData correctly sets app group and saves data', () async {
    final meal = const MealEntity(
      code: 'meal1',
      name: 'Test Meal',
      url: '',
      mealQuantity: '100',
      mealUnit: 'g',
      servingQuantity: 100,
      servingUnit: 'g',
      servingSize: '100g',
      portions: [],
      source: MealSourceEntity.custom,
      nutriments: MealNutrimentsEntity(
        energyKcal100: 100, // 100 kcal per unit
        carbohydrates100: 10,
        fat100: 5,
        proteins100: 5,
        sugars100: 0,
        saturatedFat100: 0,
        fiber100: 0,
      ),
    );

    final intake1 = IntakeEntity(
      id: 'intake1',
      unit: 'g',
      amount: 2.0, // 200g (multipler works differently in this context based on energyPerUnit)
      type: IntakeTypeEntity.breakfast,
      meal: meal,
      dateTime: DateTime.now(),
    );

    final intake2 = IntakeEntity(
      id: 'intake2',
      unit: 'g',
      amount: 3.5,
      type: IntakeTypeEntity.lunch,
      meal: meal,
      dateTime: DateTime.now(),
    );

    final calorieGoal = 2000.0;

    await homeWidgetService.updateWidgetData([intake1, intake2], calorieGoal);

    expect(log, isNotEmpty);

    // Check setAppGroupId
    final setGroupIdCall = log.firstWhere((call) => call.method == 'setAppGroupId');
    expect(setGroupIdCall.arguments['groupId'], 'group.com.opennutritracker');

    // Check saveWidgetData
    final saveDataCalls = log.where((call) => call.method == 'saveWidgetData').toList();
    expect(saveDataCalls.length, 2);

    final consumedCall = saveDataCalls.firstWhere((call) => call.arguments['id'] == 'consumedCalories');
    expect(consumedCall.arguments['data'], 5.5);

    final goalCall = saveDataCalls.firstWhere((call) => call.arguments['id'] == 'calorieGoal');
    expect(goalCall.arguments['data'], 2000.0);

    // Check updateWidget
    final updateCall = log.firstWhere((call) => call.method == 'updateWidget');
    expect(updateCall.arguments['ios'], 'CalorieWidget');
  });
}
