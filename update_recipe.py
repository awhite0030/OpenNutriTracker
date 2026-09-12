import re

with open('lib/features/recipes/presentation/widgets/food_search_tab_view.dart', 'r') as f:
    content = f.read()

# Make it format properly, remove the trailing comma in widget.onBarcodePressed,
content = content.replace(
    'NoResultsWidget(onBarcodePressed: widget.onBarcodePressed,)',
    'NoResultsWidget(onBarcodePressed: widget.onBarcodePressed)'
)

with open('lib/features/recipes/presentation/widgets/food_search_tab_view.dart', 'w') as f:
    f.write(content)
