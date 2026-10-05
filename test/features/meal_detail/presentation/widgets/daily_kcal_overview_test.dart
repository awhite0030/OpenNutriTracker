import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/daily_kcal_overview.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget _wrapWithMaterial(Widget child, {bool useKj = false}) {
  return ChangeNotifierProvider<EnergyUnitProvider>(
    create: (_) {
      final p = EnergyUnitProvider();
      if (useKj) p.updateUsesKilojoules(true);
      return p;
    },
    child: MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('displays unit correctly with current selection in kj mode', (tester) async {
    await tester.pumpWidget(
      _wrapWithMaterial(
        const DailyKcalOverview(dayKcalGoal: 2000, dayKcalConsumed: 500, currentSelectionKcal: 100),
        useKj: true,
      ),
    );
    await tester.pumpAndSettle();

    // 100 kcal is 418 kJ
    expect(find.textContaining('(+418 kJ current selection)'), findsOneWidget);
    // 600 kcal is 2510 kJ, 2000 kcal is 8368 kJ.
    expect(find.textContaining('Day total: 2510 / 8368'), findsOneWidget);
  });

  testWidgets('displays unit correctly with current selection in kcal mode', (tester) async {
    await tester.pumpWidget(
      _wrapWithMaterial(
        const DailyKcalOverview(dayKcalGoal: 2000, dayKcalConsumed: 500, currentSelectionKcal: 100),
        useKj: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('(+100 kcal current selection)'), findsOneWidget);
    expect(find.textContaining('Day total: 600 / 2000'), findsOneWidget);
  });
}
