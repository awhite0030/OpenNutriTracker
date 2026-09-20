import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/calendar_day_calc.dart';

void main() {
  group('CalendarDayCalc DST transitions', () {
    test('daysBetween counts exactly 1 calendar day across a spring-forward transition', () {
      // Europe/Berlin spring-forward in 2024 is March 31.
      final a = DateTime(2024, 3, 31, 12, 0);
      final b = DateTime(2024, 3, 30, 12, 0);

      // Using .difference().inDays on a 23-hour day would be 0.
      expect(CalendarDayCalc.daysBetween(a, b), 1);
    });

    test('daysBetween counts exactly 1 calendar day across a fall-back transition', () {
      // Europe/Berlin fall-back in 2024 is October 27.
      final a = DateTime(2024, 10, 28, 12, 0);
      final b = DateTime(2024, 10, 27, 12, 0);

      // The day is 25 hours.
      expect(CalendarDayCalc.daysBetween(a, b), 1);
    });

    test('daysBetween counts 0 for same calendar day', () {
      final a = DateTime(2024, 3, 31, 23, 0);
      final b = DateTime(2024, 3, 31, 1, 0);

      expect(CalendarDayCalc.daysBetween(a, b), 0);
    });
  });
}
