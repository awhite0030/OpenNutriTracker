import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/presentation/widgets/app_card.dart';
import 'package:opennutritracker/core/presentation/widgets/error_dialog.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/food_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/products_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/recent_meal_bloc.dart';
import 'package:opennutritracker/features/add_meal/presentation/bloc/search_debounce.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/default_results_widget.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/meal_search_bar.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/no_results_widget.dart';
import 'package:opennutritracker/features/add_meal/util/meal_relevance_ranker.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Reusable 3-tab food search (Products / Food / Recently) that delegates the
/// "selected" action to a callback rather than pushing MealDetailScreen.
/// Used by the recipe builder to add ingredients without touching the
/// existing AddMealScreen flow.
class FoodSearchTabView extends StatefulWidget {
  final void Function(MealEntity meal) onMealSelected;
  // When non-null, the search bar shows a barcode-scan suffix icon and
  // taps are forwarded here. The recipe builder uses this to push the
  // scanner in pick mode and feed the result back through [onMealSelected].
  final VoidCallback? onBarcodePressed;

  const FoodSearchTabView({
    super.key,
    required this.onMealSelected,
    this.onBarcodePressed,
  });

  @override
  State<FoodSearchTabView> createState() => _FoodSearchTabViewState();
}

class _FoodSearchTabViewState extends State<FoodSearchTabView>
    {
  final ValueNotifier<String> _searchStringListener = ValueNotifier('');

  late ProductsBloc _productsBloc;
  late FoodBloc _foodBloc;
  late RecentMealBloc _recentMealBloc;
  @override
  void initState() {
    super.initState();
    _productsBloc = locator<ProductsBloc>();
    _foodBloc = locator<FoodBloc>();
    _recentMealBloc = locator<RecentMealBloc>();
  }

  @override
  void dispose() {
    _searchStringListener.dispose();
    super.dispose();
  }

  static const _pendingSpinner = Center(
    child: Padding(
      padding: EdgeInsets.only(top: 32),
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          MealSearchBar(
            searchStringListener: _searchStringListener,
            onSearchSubmit: _onSearchSubmit,
            onSearchChanged: _onSearchChanged,
            onBarcodePressed: widget.onBarcodePressed,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchStringListener,
              builder: (context, query, _) => _buildResults(context, query),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return BlocBuilder<RecentMealBloc, RecentMealState>(
        bloc: _recentMealBloc,
        builder: (context, state) {
          if (state is RecentMealInitial) {
            _recentMealBloc.add(const LoadRecentMealEvent(searchString: ''));
            return const SizedBox.shrink();
          }
          if (state is RecentMealLoadingState) {
            return _pendingSpinner;
          }
          if (state is RecentMealLoadedState) {
            if (state.recentMeals.isEmpty) return const NoResultsWidget();
            return ListView.builder(
              itemCount: state.recentMeals.length,
              itemBuilder: (context, index) => _PickableMealCard(
                meal: state.recentMeals[index],
                onTap: widget.onMealSelected,
              ),
            );
          }
          if (state is RecentMealFailedState) {
            return ErrorDialog(
              errorText: S.of(context).noMealsRecentlyAddedLabel,
              onRefreshPressed: () => _recentMealBloc.add(
                const LoadRecentMealEvent(searchString: ''),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
    }

    return BlocBuilder<ProductsBloc, ProductsState>(
      bloc: _productsBloc,
      builder: (context, ps) {
        return BlocBuilder<FoodBloc, FoodState>(
          bloc: _foodBloc,
          builder: (context, fs) {
            if (_productsPending(ps, query) || _foodPending(fs, query)) {
              return _pendingSpinner;
            }

            if (ps is ProductsFailedState && fs is FoodFailedState) {
              return ErrorDialog(
                errorText: S.of(context).errorFetchingProductData,
                onRefreshPressed: () {
                  _productsBloc.add(const RefreshProductsEvent());
                  _foodBloc.add(const RefreshFoodEvent());
                },
              );
            }

            final products =
                ps is ProductsLoadedState ? ps.products : const <MealEntity>[];
            final foods = fs is FoodLoadedState ? fs.food : const <MealEntity>[];
            final merged = mergeAndRankMeals(products, foods, query);

            if (merged.isEmpty) {
              if (ps is ProductsInitial && fs is FoodInitial) {
                return const DefaultsResultsWidget();
              }
              return const NoResultsWidget();
            }

            final partialFailure = (ps is ProductsFailedState || fs is FoodFailedState) &&
                !(ps is ProductsFailedState && fs is FoodFailedState);
            final remoteEmpty = (ps is ProductsLoadedState && ps.remoteSourceEmpty) ||
                (fs is FoodLoadedState && fs.remoteSourceEmpty);
            final extraItemCount = (partialFailure ? 1 : 0) + (remoteEmpty && !partialFailure ? 1 : 0);

            return ListView.builder(
              itemCount: merged.length + extraItemCount,
              itemBuilder: (context, index) {
                if (index == merged.length) {
                  if (partialFailure) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            S.of(context).errorFetchingProductData,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              if (ps is ProductsFailedState) _productsBloc.add(const RefreshProductsEvent());
                              if (fs is FoodFailedState) _foodBloc.add(const RefreshFoodEvent());
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(S.of(context).retryLabel),
                          ),
                        ],
                      ),
                    );
                  } else if (remoteEmpty) {
                     return const NoResultsWidget();
                  }
                }
                return _PickableMealCard(
                  meal: merged[index],
                  onTap: widget.onMealSelected,
                );
              },
            );
          },
        );
      },
    );
  }

  static bool _productsPending(ProductsState state, String query) {
    if (state is ProductsLoadingState) return true;
    if (query.trim().length < minQueryLength) return false;
    if (state is ProductsInitial) return true;
    if (state is ProductsLoadedState) return state.query != query;
    return false;
  }

  static bool _foodPending(FoodState state, String query) {
    if (state is FoodLoadingState) return true;
    if (query.trim().length < minQueryLength) return false;
    if (state is FoodInitial) return true;
    if (state is FoodLoadedState) return state.query != query;
    return false;
  }

  void _onSearchSubmit(String inputText) {
    final trimmed = inputText.trim();
    if (trimmed.isEmpty) {
      _recentMealBloc.add(const LoadRecentMealEvent(searchString: ''));
      return;
    }
    _productsBloc.add(LoadProductsEvent(searchString: inputText));
    _foodBloc.add(LoadFoodEvent(searchString: inputText));
  }

  /// Debounced search-as-you-type.
  void _onSearchChanged(String inputText) {
    final trimmed = inputText.trim();
    if (trimmed.isEmpty) {
      _recentMealBloc.add(const LoadRecentMealEvent(searchString: ''));
      return;
    }
    _productsBloc.add(SearchInputChangedEvent(searchString: inputText));
    _foodBloc.add(SearchFoodInputChangedEvent(searchString: inputText));
  }
}

class _PickableMealCard extends StatelessWidget {
  final MealEntity meal;
  final void Function(MealEntity meal) onTap;

  const _PickableMealCard({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final accent = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing8, vertical: Dimens.spacing4),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: Dimens.borderRadiusL,
          onTap: () => onTap(meal),
          child: Padding(
            padding: const EdgeInsets.all(Dimens.spacing12),
            child: Row(
              children: [
                meal.thumbnailImageUrl != null
                    ? ClipRRect(
                        borderRadius: Dimens.borderRadiusS,
                        child: CachedNetworkImage(
                          cacheManager: locator<CacheManager>(),
                          fit: BoxFit.cover,
                          width: 52,
                          height: 52,
                          imageUrl: meal.thumbnailImageUrl ?? '',
                        ),
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: Dimens.borderRadiusS,
                        ),
                        child: Icon(
                          meal.source == MealSourceEntity.recipe
                              ? Icons.menu_book_rounded
                              : Icons.restaurant_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
                const SizedBox(width: Dimens.spacing12),
                Expanded(
                  child: AutoSizeText.rich(
                    TextSpan(
                      text: meal.name ?? '?',
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                          text: ' ${meal.brands ?? ''}',
                          style: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
                        ),
                      ],
                    ),
                    style: textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Dimens.spacing8),
                Icon(Icons.add_circle_outline_rounded, color: accent, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
