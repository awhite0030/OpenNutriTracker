import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      home: Scaffold(body: child),
    );
  }

  testWidgets('MealInfoButton with empty URL renders plain text', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const MealInfoButton(url: null, source: MealSourceEntity.recipe)));

    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('MealInfoButton with active URL renders TextButton', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(const MealInfoButton(url: 'https://example.com', source: MealSourceEntity.off)),
    );

    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
  });
}
