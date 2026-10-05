Wait, let's look at `#1224 and #1207`.
What if the memory hint is telling me exactly how to fix `DayBoundaryCalc`?
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
"In Dart, use calendar-day arithmetic via DateTime constructors (e.g., DateTime(date.year, date.month, date.day - 1)) instead of Duration subtraction (date.subtract(Duration(days: 1))) for manipulating full calendar days, as Duration uses wall-clock hours and may fail across DST boundaries."

Is it possible that `isMomentInLogicalDayMinutes` and `isSameLogicalDayMinutes` should just convert BOTH to UTC before comparing?
```dart
  static bool isSameLogicalDayMinutes(
    DateTime a,
    DateTime b,
    int? offsetTotalMinutes,
  ) {
    final dayA = logicalDayOfMinutes(a, offsetTotalMinutes);
    final dayB = logicalDayOfMinutes(b, offsetTotalMinutes);
    return DateTime.utc(dayA.year, dayA.month, dayA.day) == DateTime.utc(dayB.year, dayB.month, dayB.day);
  }
```
Wait, `return dayA.year == dayB.year && dayA.month == dayB.month && dayA.day == dayB.day;` is ALREADY functionally equivalent to comparing `DateTime.utc(dayA.year, dayA.month, dayA.day) == DateTime.utc(dayB.year, dayB.month, dayB.day)`!
So changing that doesn't fix the timezone crossing bug.

BUT wait! If `DayBoundaryCalc` uses:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
If we change it to:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime.utc(shifted.year, shifted.month, shifted.day);
  }
```
Then `_logicalDayOfTotalMinutes` returns a UTC midnight!
And if it returns a UTC midnight, then ALL `TrackedDayDBO.day` objects created in the future will be UTC midnights!
AND if we update `toParsedDay`:
```dart
extension FormatString on DateTime {
  String toParsedDay() {
    if (millisecondsSinceEpoch % 86400000 == 0) {
      return DateFormat('yyyy-MM-dd').format(toUtc());
    }
    return DateFormat('yyyy-MM-dd').format(this);
  }
}
```
AND if we update `_isDayLabel`:
```dart
  static bool _isDayLabel(DateTime value) {
    return (value.hour == 0 && value.minute == 0 && value.second == 0 && value.millisecond == 0 && value.microsecond == 0) ||
           (value.millisecondsSinceEpoch % 86400000 == 0);
  }
```
AND if we update `isMomentInLogicalDayMinutes`:
```dart
  static bool isMomentInLogicalDayMinutes(
    DateTime dayLabel,
    DateTime moment,
    int? offsetTotalMinutes,
  ) {
    final momentDay = _isDayLabel(moment)
        ? (moment.millisecondsSinceEpoch % 86400000 == 0 ? moment.toUtc() : moment)
        : logicalDayOfMinutes(moment, offsetTotalMinutes);

    final label = dayLabel.millisecondsSinceEpoch % 86400000 == 0 ? dayLabel.toUtc() : dayLabel;

    return momentDay.year == label.year &&
        momentDay.month == label.month &&
        momentDay.day == label.day;
  }
```

Wait! What about the intakes logged via Home page (`DateTime.now()`)? They will STILL move when timezones change.
Is there a way to make them NOT move?
If the issue says: "Log food and an activity at local time UTC-3 on two consecutive days. 2. Change the device time zone to UTC+2. 3. Open both days in the Diary."
If the author of the issue explicitly logged them from the Home Page...
Wait, if they logged from Home Page, `IntakeDBO.dateTime` is `DateTime.now()`.
If we change how `IntakeDBO` calendar day is resolved, CAN we just use UTC for EVERYTHING?
If we use `.toUtc()` on `DateTime.now()`, it's STILL an absolute moment. It will STILL evaluate to the 6th in UTC.
Wait! In UTC-3, 23:00 Local is 02:00 UTC (the next day!).
If we resolve it using UTC, it will ALWAYS evaluate to the 6th, EVEN IN BRAZIL!
So resolving using UTC completely breaks local time boundary calculations!
We MUST evaluate it in the local timezone to get the 5th in Brazil.
But when in Germany, local timezone gives the 6th.
So it is IMPOSSIBLE to make Home Page intakes stay on the 5th without knowing they were logged in Brazil!
Wait, but if `IntakeDBO` logged from Diary has `dateTime` = UTC midnight, it DOES stay on the 5th if we fix it as above!
Is it possible that the issue is EXACTLY about `TrackedDayDBO` moving and `IntakeDBO` (logged from Diary) moving?
The issue says: "one day's calorie total no longer matched the sum of its entries, and activities that had been logged on different days appeared on the same day."
Wait! "activities that had been logged on different days appeared on the same day."
If you log an activity from the Diary, it creates `UserActivityEntity(date: day)`.
`day` is UTC midnight!
If you log an activity on the 5th (UTC midnight).
And you log another activity on the 4th (UTC midnight).
In Germany, they might BOTH shift? No, they shift consistently.
But wait! What if you logged one from Home (absolute time) and one from Diary (UTC midnight)?
In Brazil, they are both on the 5th.
In Germany, the Home one moves to the 6th, and the Diary one moves to the 4th (because it fails `_isDayLabel` and gets shifted)!
So they move in DIFFERENT directions!
THIS perfectly explains "activities that had been logged on different days appeared on the same day"!
Because a Diary activity from the 6th moves to the 5th. And a Home activity from the 5th moves to the 6th! Or something like that.
YES! The combination of UTC midnights (from Diary) and absolute times (from Home) causes them to drift differently when timezones change!
Because Diary timestamps (UTC midnights) fail `_isDayLabel` when traveling, and get subjected to `logicalDayOfMinutes`, which subtracts the boundary offset, and because they are evaluated as local times, they shift weirdly.

So the fix IS to correctly handle UTC midnights across the app!
