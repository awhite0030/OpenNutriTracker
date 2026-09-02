import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/widgets/food_search_tab_view.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

class FakeProductsBloc extends Bloc<ProductsEvent, ProductsState> implements ProductsBloc {
  @override
  final log = Logger('ProductsBloc');
  FakeProductsBloc() : super(ProductsFailedState()) {
    on<SearchInputChangedEvent>((event, emit) {});
  }
}

class FakeFoodBloc extends Bloc<FoodEvent, FoodState> implements FoodBloc {
  @override
  final log = Logger('FoodBloc');
  FakeFoodBloc() : super(FoodLoadedState(
    food: [MealEntity(
      name: 'Apple',
      code: '123',
      source: MealSourceEntity.off,
      nutriments: MealNutrimentsEntity.empty(),
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: 100,
      servingUnit: 'g',
      servingSize: '100g',
    )],
    usesImperialUnits: false,
    query: 'app',
    remoteSourceEmpty: false,
  )) {
    on<SearchFoodInputChangedEvent>((event, emit) {});
  }
}

class FakeRecentMealBloc extends Bloc<RecentMealEvent, RecentMealState> implements RecentMealBloc {
  @override
  final log = Logger('RecentMealBloc');
  FakeRecentMealBloc() : super(RecentMealInitial()) {
    on<LoadRecentMealEvent>((event, emit) {});
  }

  @override
  bool Function(IntakeEntity) matchesSearchString(String searchString) => (_) => false;
}

void main() {
  setUp(() {
    locator.registerFactory<ProductsBloc>(() => FakeProductsBloc());
    locator.registerFactory<FoodBloc>(() => FakeFoodBloc());
    locator.registerFactory<RecentMealBloc>(() => FakeRecentMealBloc());
  });

  tearDown(() {
    locator.reset();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: FoodSearchTabView(onMealSelected: (_) {}),
      ),
    );
  }

  testWidgets('partial provider failure shows retry button at bottom', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Enter query
    await tester.enterText(find.byType(TextField), 'app');
    await tester.pump(); // trigger rebuild for ValueListenable
    await tester.pumpAndSettle();

    expect(find.textContaining('Apple'), findsWidgets);
    expect(find.byIcon(Icons.refresh_rounded), findsWidgets); // Retry button
  });
}
