class CalendarDayCalc {
  /// Returns the number of calendar days between two local DateTime objects.
  /// Converts them to UTC first to avoid daylight saving time (DST) transition errors.
  static int daysBetween(DateTime a, DateTime b) {
    return DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
  }
}
