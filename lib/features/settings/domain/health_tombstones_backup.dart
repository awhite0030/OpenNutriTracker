/// The active profile's health import tombstones as they travel in a JSON
/// backup, as `health_tombstones.json`.
///
/// Keeps deleted health-imported workouts out of the user's diary after a
/// restore.
class HealthTombstonesBackup {
  /// Bumped only for a change an older reader would misread. A reader
  /// that meets a newer version skips the file rather than guess.
  static const formatVersion = 1;

  final Map<String, DateTime> tombstones;

  const HealthTombstonesBackup(this.tombstones);

  /// Parses and validates a decoded `health_tombstones.json`.
  ///
  /// Returns null when the file was written by a newer format this build
  /// does not know, so the rest of the backup still restores. Throws a
  /// [FormatException] when the file is not a valid tombstones object.
  static HealthTombstonesBackup? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('health tombstones must be a JSON object');
    }
    final version = json['version'];
    if (version is! int || version < 1) {
      throw FormatException('unsupported health tombstones version: $version');
    }
    if (version > formatVersion) return null;

    final rawTombstones = json['tombstones'];
    if (rawTombstones is! Map<String, dynamic>) {
      throw const FormatException('tombstones must be a JSON object');
    }

    final tombstones = <String, DateTime>{};
    for (final entry in rawTombstones.entries) {
      final value = entry.value;
      if (value is! String) {
        throw FormatException('tombstone for ${entry.key} must be an ISO-8601 string');
      }
      try {
        tombstones[entry.key] = DateTime.parse(value);
      } catch (e) {
        throw FormatException('tombstone for ${entry.key} is not a valid ISO-8601 string');
      }
    }

    return HealthTombstonesBackup(tombstones);
  }

  Map<String, dynamic> toJson() => {
    'version': formatVersion,
    'tombstones': tombstones.map((key, value) => MapEntry(key, value.toIso8601String())),
  };
}
