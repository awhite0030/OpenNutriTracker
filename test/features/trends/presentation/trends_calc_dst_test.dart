import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/trends/presentation/trends_calc.dart';

void main() {
  group('trends_calc DST transitions', () {
    test('streakStats counts calendar days correctly across a spring-forward transition', () {
      // Europe/Berlin spring-forward in 2024 is March 31.
      final windowStart = DateTime(2024, 3, 29);
      final today = DateTime(2024, 4, 1);
      final onTrackDays = {DateTime(2024, 3, 29), DateTime(2024, 3, 30), DateTime(2024, 3, 31), DateTime(2024, 4, 1)};

      final stats = streakStats(onTrackDays, windowStart, today);
      expect(stats.current, 4);
      expect(stats.longest, 4);
    });

    test('streakStats handles missing days correctly across DST', () {
      final windowStart = DateTime(2024, 3, 29);
      final today = DateTime(2024, 4, 1);
      final onTrackDays = {DateTime(2024, 3, 29), DateTime(2024, 3, 31), DateTime(2024, 4, 1)};

      final stats = streakStats(onTrackDays, windowStart, today);
      expect(stats.current, 2); // 31st and 1st
      expect(stats.longest, 2); // 31st and 1st
    });
  });
}
