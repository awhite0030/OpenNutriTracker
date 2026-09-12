import re

with open('lib/features/add_activity/presentation/add_activity_screen.dart', 'r') as f:
    content = f.read()

# Make it const NoResultsWidget() since it does not pass anything.
content = content.replace(
    '                                : const NoResultsWidget();',
    '                                : const NoResultsWidget();'
)

with open('lib/features/add_activity/presentation/add_activity_screen.dart', 'w') as f:
    f.write(content)
