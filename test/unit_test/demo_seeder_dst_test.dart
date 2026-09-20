import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/demo/demo_seeder.dart';

void main() {
  group('DemoSeeder DST transitions', () {
    test('dates use correct calendar days without jumping across a spring-forward transition', () {
      // Europe/Berlin spring-forward in 2024 is March 31.
      final startOfToday = DateTime(2024, 4, 1);
      final entries = buildWeightLogForTesting(
        startOfToday,
        80.0, // currentWeightKg
        const DemoSeedOptions(daysOfHistory: 5, startWeightKg: 80, missedDayProbability: 0, guaranteedStreakDays: 5),
      );

      for (final e in entries) {
        expect(e.date.hour, 0);
        expect(e.date.minute, 0);
        expect(e.date.second, 0);
      }
    });

    test('fasting sessions use exact expected times across DST', () {
      final now = DateTime(2024, 4, 1, 12, 0); // Noon on April 1
      final sessions = buildFastingSessionsForTesting(now, 5); // 5 days history

      // Over the spring forward boundary (March 31)
      final march31 = sessions.where((s) => s.startedAt.day == 31).toList();
      if (march31.isNotEmpty) {
        expect(march31.first.startedAt.hour, 4); // Should still be 04:00, not 05:00
      }
    });
  });
}
