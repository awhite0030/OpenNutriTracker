If `DiaryBloc` groups them using `trackedDay.day.toParsedDay()`, it builds a map.
BUT Hive ALREADY stored them with string keys!
Why doesn't `getTrackedDaysByRange` return the keys?
Because it returns `TrackedDayEntity`!
```dart
    final List<TrackedDayDBO> trackedDaysDBO =
        await _trackedDayDataSource.getTrackedDaysInRange(start, end);
```
And `getTrackedDaysInRange` does:
```dart
  Future<List<TrackedDayDBO>> getTrackedDaysInRange(
    DateTime start,
    DateTime end,
  ) async {
    List<TrackedDayDBO> trackedDays = _trackedDayBox.values
        .where(
          (trackedDay) =>
              !trackedDay.day.isBefore(start) && !trackedDay.day.isAfter(end),
        )
        .toList();
    return trackedDays;
  }
```
Wait! `trackedDay.day.isBefore(start)` is ALSO broken!
If `trackedDay.day` shifted to the 4th, it might fall outside the range!
But more importantly, the key in Hive IS the string `"2023-10-05"`.
If we can parse the string key `"2023-10-05"` into a UTC DateTime, it will ALWAYS be the correct day!
Since `TrackedDayDBO` extends `HiveObject`, it has `key`.
The `key` is the string `"yyyy-MM-dd"`.
If we UPDATE `TrackedDayDBO.day` to ALWAYS reflect its string key when it's loaded from Hive?
Wait! If we just parse the `key`!
Can we change `TrackedDayDBO` to use the key?
No, the `key` is not available in `fromJson` or before it's saved.
But wait! What if we change `toParsedDay()` to NOT use the shifted local time?
How?
If we use `DateTime.utc(this.year, this.month, this.day)`... No, the local components have shifted.
Wait! What if we use `DateTime(this.year, this.month, this.day)`... No.

Wait. If the only way to correctly handle dates in an offline-first app without explicit timezones is to NOT use epochs for calendar dates.
Wait. The issue mentions "#1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST".
Is there a memory hint?
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays."
"In Dart, use calendar-day arithmetic via DateTime constructors (e.g., DateTime(date.year, date.month, date.day - 1)) instead of Duration subtraction (date.subtract(Duration(days: 1))) for manipulating full calendar days, as Duration uses wall-clock hours and may fail across DST boundaries."

Look at `DayBoundaryCalc._logicalDayOfTotalMinutes`:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
If we replace `shifted.subtract(Duration(minutes: totalMinutes))` with something else? No, `totalMinutes` is the boundary offset (e.g. 240 minutes for 04:00 AM). `subtract(Duration)` is perfectly correct for offsetting a timestamp.
But look at the return value:
`return DateTime(shifted.year, shifted.month, shifted.day);`
This returns a LOCAL DateTime!
If instead it returned a UTC DateTime?
```dart
    return DateTime.utc(shifted.year, shifted.month, shifted.day);
```
If it returns a UTC DateTime, then when `DayBoundaryCalc` computes `currentLogicalDay`, it returns UTC!
If it returns UTC, then `TrackedDayDBO.day` is created as UTC!
If it is UTC, when saved to Hive, its epoch is UTC midnight.
When loaded in ANY timezone, we can format it correctly IF we know it's UTC midnight.
But `toParsedDay()` doesn't know it's UTC midnight, because Hive returns `isUtc = false`.
So we still have the shifting problem for `TrackedDayDBO.day`.

What if we fix `toParsedDay`?
Since `TrackedDayDBO` uses `toParsedDay`, and `IntakeDBO` doesn't.
Can we fix `toParsedDay` to ignore the timezone shift?
How can we do that? We cannot unless we know the original timezone!
Wait! "A user reported... a flight from Brazil to Germany... one day's calorie total no longer matched..."
This implies the app developers have considered this a BUG in their logic.
If it's a bug in their logic, how did they intend to fix it?
Wait, if I just use `DateTime` with `String` keys?
If I change `DayBoundaryCalc._isDayLabel`?
If `_isDayLabel` fails, the offset is subtracted again!
If we change `_isDayLabel` to:
```dart
  static bool _isDayLabel(DateTime value) {
    // If it's midnight in UTC or midnight in LOCAL or midnight in ANY reasonable timezone?
    // Actually, if it's a day label, it has exactly 0 hours, 0 minutes, 0 seconds in SOME timezone.
    // But since it's just an epoch, `value.toUtc().hour == 0` is true if it was UTC midnight!
    return (value.hour == 0 && value.minute == 0 && value.second == 0 && value.millisecond == 0 && value.microsecond == 0) ||
           (value.toUtc().hour == 0 && value.toUtc().minute == 0 && value.toUtc().second == 0 && value.toUtc().millisecond == 0 && value.toUtc().microsecond == 0);
  }
```
If we do this, UTC midnights loaded in Brazil will be recognized as day labels!
Wait! What about LOCAL midnights loaded in Brazil that were created in Germany?
They are NEITHER local midnight NOR UTC midnight in Brazil!
So `_isDayLabel` will STILL fail for them!

Is there any way to make day labels ALWAYS UTC?
If we make ALL day labels UTC:
1. `DayBoundaryCalc` should return UTC midnights for day labels.
2. `JsonMealImporter` should create UTC midnights for imported days.
3. If they are ALWAYS UTC midnights, their epoch is ALWAYS a multiple of 86400000!
Wait! A UTC midnight epoch is EXACTLY divisible by 86400000!
`value.millisecondsSinceEpoch % 86400000 == 0`!
Let's check!
