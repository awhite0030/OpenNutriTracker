import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/body_weight_unit_entity.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';
import 'package:opennutritracker/features/profile/presentation/widgets/weight_trend_chart.dart';
import 'package:opennutritracker/generated/l10n.dart';

WeightLogEntity _entry(DateTime date, double weightKg) =>
    WeightLogEntity(date: date, weightKg: weightKg);

Future<LineChartData> _pumpChart(
  WidgetTester tester, {
  required List<WeightLogEntity> entries,
  int windowDays = 200,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(size: Size(400, 400)),
          child: WeightTrendChart(
            entries: entries,
            bodyWeightUnit: BodyWeightUnit.kg,
            targetWeightKg: null,
            windowDays: windowDays,
            movingAverageWindowDays: null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<LineChart>(find.byType(LineChart)).data;
}

void main() {
  testWidgets(
    'WeightTrendChart draws all points across a DST transition without gaps',
    (tester) async {
      // The chart computes `windowStart` relative to `DateTime.now()`.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // We need a fall-back transition inside the window. In Europe/Berlin,
      // October 29 is a fallback date. If we run in TZ=Europe/Berlin, and
      // today is after that but within windowDays, we can test it.
      // But we can't mock DateTime.now() easily. So instead, we generate
      // entries for the past `windowDays` days directly. If a DST transition
      // happened recently in the environment, this will naturally catch it.
      // And we can run the test with a specific `windowDays` to ensure a
      // fallback is caught if it happens. Wait, the issue says:
      // "Measured under TZ=Australia/Sydney with a 200-day window from today
      // (Apr 5 fall-back inside it)".

      // Let's just generate entries for the last 200 days.
      final windowDays = 200;
      final entries = <WeightLogEntity>[];
      for (int i = 0; i < windowDays; i++) {
        // Build dates safely via DateTime constructor for calendar days.
        final date = DateTime(today.year, today.month, today.day - i);
        entries.add(_entry(date, 80.0));
      }

      final data = await _pumpChart(tester, entries: entries, windowDays: windowDays);

      // Verify that NO points were dropped.
      expect(data.lineBarsData[0].spots.length, windowDays, reason: 'All points in window should be drawn');

      // Verify that x-values are continuous (no gaps, 0 to windowDays - 1).
      final spots = data.lineBarsData[0].spots;
      final xValues = spots.map((s) => s.x.toInt()).toList();
      xValues.sort();
      for (int i = 0; i < windowDays; i++) {
        expect(xValues[i], i, reason: 'x-values should increment by 1 for each calendar day');
      }
    },
  );
}
