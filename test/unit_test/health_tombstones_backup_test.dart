import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/settings/domain/health_tombstones_backup.dart';

void main() {
  group('HealthTombstonesBackup', () {
    test('toJson returns expected map', () {
      final backup = HealthTombstonesBackup({'id1': DateTime.utc(2026, 5, 13, 18, 0, 0)});

      final json = backup.toJson();

      expect(json, {
        'version': 1,
        'tombstones': {'id1': '2026-05-13T18:00:00.000Z'},
      });
    });

    test('fromJson loads valid JSON', () {
      final backup = HealthTombstonesBackup.fromJson({
        'version': 1,
        'tombstones': {'id1': '2026-05-13T18:00:00.000Z'},
      });

      expect(backup, isNotNull);
      expect(backup!.tombstones, hasLength(1));
      expect(backup.tombstones['id1'], DateTime.utc(2026, 5, 13, 18, 0, 0));
    });

    test('fromJson returns null on newer format version', () {
      final backup = HealthTombstonesBackup.fromJson({'version': 2, 'tombstones': {}});

      expect(backup, isNull);
    });

    test('fromJson throws FormatException on invalid version', () {
      expect(() => HealthTombstonesBackup.fromJson({'version': 0, 'tombstones': {}}), throwsFormatException);
      expect(() => HealthTombstonesBackup.fromJson({'version': '1', 'tombstones': {}}), throwsFormatException);
    });

    test('fromJson throws FormatException on invalid tombstones map', () {
      expect(() => HealthTombstonesBackup.fromJson({'version': 1, 'tombstones': 'not a map'}), throwsFormatException);
      expect(
        () => HealthTombstonesBackup.fromJson({
          'version': 1,
          'tombstones': {'id1': 123},
        }),
        throwsFormatException,
      );
      expect(
        () => HealthTombstonesBackup.fromJson({
          'version': 1,
          'tombstones': {'id1': 'not a date'},
        }),
        throwsFormatException,
      );
    });
  });
}
