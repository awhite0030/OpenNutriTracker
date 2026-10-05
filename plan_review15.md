Ah!!!!!
`DayBoundaryCalc._logicalDayOfTotalMinutes`:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
If `totalMinutes` is 0 (the default!).
`moment.subtract(Duration(minutes: 0))` does NOTHING!
Then it returns `DateTime(shifted.year, shifted.month, shifted.day)`.
Wait, this does exactly what the memory says NOT to do:
"In Dart, use calendar-day arithmetic via DateTime constructors (e.g., DateTime(date.year, date.month, date.day - 1)) instead of Duration subtraction (date.subtract(Duration(days: 1))) for manipulating full calendar days, as Duration uses wall-clock hours and may fail across DST boundaries."

But here, it subtracts `totalMinutes` (which is the boundary offset, e.g. 4 hours = 240 minutes).
Is subtracting minutes failing across DST?
No, minutes are fine for wall clock.
Wait. Is there somewhere else?
