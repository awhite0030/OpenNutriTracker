import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/recipe_repository.dart';
import 'package:opennutritracker/core/domain/entity/recipe_entity.dart';
import 'package:opennutritracker/core/domain/usecase/compute_recipe_nutrition_usecase.dart';

class SaveRecipeUseCase {
  final RecipeRepository _repository;
  final ComputeRecipeNutritionUseCase _computeUseCase;
  final IntakeRepository _intakeRepository;

  SaveRecipeUseCase(this._repository, this._computeUseCase, this._intakeRepository);

  // Always re-aggregates from the current ingredient list before persisting.
  // Updates past IntakeDBO rows snapshot so the recently added list stays fresh.
  Future<RecipeEntity> save(
    RecipeEntity recipe, {
    bool totalWeightOverridden = false,
  }) async {
    final result = _computeUseCase.compute(
      recipe.ingredients,
      totalWeightOverride: totalWeightOverridden ? recipe.totalWeightG : null,
    );

    final updated = recipe.copyWith(
      totalWeightG: result.totalWeightG,
      aggregatedNutrimentsPer100: result.perHundredG,
      updatedAt: DateTime.now(),
    );

    await _repository.saveRecipe(updated);
    await _intakeRepository.remapRecipeOnIntakes(
      recipeId: updated.id,
      updatedMeal: MealDBO.fromMealEntity(updated.toMealEntity()),
    );
    return updated;
  }
}
