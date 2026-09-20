import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/save_recipe_usecase.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/recipes/domain/entity/shared_recipe_payload.dart';
import 'package:opennutritracker/features/recipes/presentation/bloc/recipes_bloc.dart';
import 'package:opennutritracker/features/recipes/presentation/screens/import_recipe_scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../../../../helpers/test_l10n.dart';
import 'import_recipe_scanner_screen_test.mocks.dart';

RecipeEntity _mockRecipeEntity() {
  return RecipeEntity(
    id: 'test-id',
    name: 'Test Recipe',
    description: 'Test Desc',
    ingredients: const [],
    totalWeightG: 100,
    aggregatedNutrimentsPer100: MealNutrimentsEntity(
      energyKcal100: 100,
      carbohydrates100: 10,
      fat100: 10,
      proteins100: 10,
      sugars100: 10,
      saturatedFat100: 10,
      fiber100: 10,
    ),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    servingsCount: 1,
  );
}

@GenerateMocks([SaveRecipeUseCase, RecipesBloc])
void main() {
  late MockSaveRecipeUseCase mockSaveRecipeUseCase;
  late MockRecipesBloc mockRecipesBloc;

  setUp(() {
    mockSaveRecipeUseCase = MockSaveRecipeUseCase();
    mockRecipesBloc = MockRecipesBloc();

    if (GetIt.I.isRegistered<SaveRecipeUseCase>()) {
      GetIt.I.unregister<SaveRecipeUseCase>();
    }
    if (GetIt.I.isRegistered<RecipesBloc>()) {
      GetIt.I.unregister<RecipesBloc>();
    }
    GetIt.I.registerSingleton<SaveRecipeUseCase>(mockSaveRecipeUseCase);
    GetIt.I.registerSingleton<RecipesBloc>(mockRecipesBloc);

    when(
      mockSaveRecipeUseCase.save(any, totalWeightOverridden: anyNamed('totalWeightOverridden')),
    ).thenAnswer((_) async => _mockRecipeEntity());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  testWidgets('ImportRecipeScannerScreen with initialCode uses explicit total weight (Issue #1194)', (tester) async {
    // Generate a valid QR payload for a recipe.
    final payload = const SharedRecipePayload(
      version: 1,
      name: 'Test Recipe',
      description: null,
      servingsCount: null,
      totalWeightG: 300,
      energyKcal100: null,
      carbohydrates100: null,
      fat100: null,
      proteins100: null,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
      ingredients: [],
    );
    final initialCode = payload.toJsonString();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        home: Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: RouteSettings(arguments: ImportRecipeScannerArguments(initialCode: initialCode)),
              builder: (context) => const ImportRecipeScannerScreen(),
            );
          },
        ),
      ),
    );

    // Give the widget time to render and trigger didChangeDependencies.
    await tester.pumpAndSettle();

    // The alert dialog showing the recipe name should be visible.
    expect(find.text('Test Recipe'), findsOneWidget);

    // Tap OK.
    await tester.tap(find.text(l10nEn.dialogOKLabel));
    await tester.pumpAndSettle();

    // Verify the explicit total weight was preserved via totalWeightOverridden.
    verify(mockSaveRecipeUseCase.save(any, totalWeightOverridden: true)).called(1);
  });
}
