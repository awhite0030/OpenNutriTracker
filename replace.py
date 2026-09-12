import re

with open('lib/features/add_meal/presentation/add_meal_screen.dart', 'r') as f:
    content = f.read()

# Revert previous replacement
content = content.replace(
    'return NoResultsWidget(onBarcodePressed: _onBarcodeIconPressed, onCustomFoodPressed: () => _onCustomAddButtonPressed(false));',
    'return const NoResultsWidget();'
)

# Apply context-aware replacements

# Replace NoResultsWidget when merged is empty
content = re.sub(
    r'(final merged = mergeAndRankMeals\(products, foods, query\);\s*if \(merged.isEmpty\) \{\s*if \(ps is ProductsInitial && fs is FoodInitial\) \{\s*return const DefaultsResultsWidget\(\);\s*\}\s*)return const NoResultsWidget\(\);',
    r'\1return NoResultsWidget(onBarcodePressed: _onBarcodeIconPressed, onCustomFoodPressed: () => _onCustomAddButtonPressed(false));',
    content
)

# Replace NoResultsWidget for Products search
content = re.sub(
    r'(if \(state\.products\.isEmpty\) \{\s*return _productsPending\(state, query\)\s*\?\s*_pendingSpinner\s*:\s*)const NoResultsWidget\(\);',
    r'\1NoResultsWidget(onBarcodePressed: _onBarcodeIconPressed, onCustomFoodPressed: () => _onCustomAddButtonPressed(state.usesImperialUnits));',
    content
)
content = re.sub(
    r'(if \(index == state\.products\.length\) \{\s*)return const NoResultsWidget\(\);',
    r'\1return NoResultsWidget(onBarcodePressed: _onBarcodeIconPressed, onCustomFoodPressed: () => _onCustomAddButtonPressed(state.usesImperialUnits));',
    content
)

# Replace NoResultsWidget for Food search
content = re.sub(
    r'(if \(state\.food\.isEmpty\) \{\s*return _foodPending\(state, query\)\s*\?\s*_pendingSpinner\s*:\s*)const NoResultsWidget\(\);',
    r'\1NoResultsWidget(onBarcodePressed: _onBarcodeIconPressed, onCustomFoodPressed: () => _onCustomAddButtonPressed(state.usesImperialUnits));',
    content
)
content = re.sub(
    r'(if \(index == state\.food\.length\) \{\s*)return const NoResultsWidget\(\);',
    r'\1return NoResultsWidget(onBarcodePressed: _onBarcodeIconPressed, onCustomFoodPressed: () => _onCustomAddButtonPressed(state.usesImperialUnits));',
    content
)

# Replace NoResultsWidget for Recent Meals
content = re.sub(
    r'(\? ListView\.builder\([\s\S]*?\)\s*:\s*)const NoResultsWidget\(\);',
    r'\1NoResultsWidget(onBarcodePressed: _onBarcodeIconPressed, onCustomFoodPressed: () => _onCustomAddButtonPressed(state.usesImperialUnits));',
    content
)

with open('lib/features/add_meal/presentation/add_meal_screen.dart', 'w') as f:
    f.write(content)
