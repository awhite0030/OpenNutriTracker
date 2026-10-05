Let's analyze what happens with `DateTime` and DST across timezones.
In `#1224`, to get around DST issues when finding "tomorrow", instead of `dateTime.add(Duration(days: 1))`, they use `DateTime(year, month, day + 1)`.
Wait, look at `DayBoundaryCalc._logicalDayOfTotalMinutes`:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
This produces a `DateTime` using local time `DateTime(...)`.
If a `TrackedDayDBO.day` (which is just a day label, supposed to represent a specific calendar day) was produced by `table_calendar` as `DateTime.utc(y, m, d)`, its epoch is UTC midnight.
When Hive reads it, it reads it as LOCAL `DateTime.fromMillisecondsSinceEpoch(epoch)`.
If you moved from Brazil to Germany, this local DateTime has its year/month/day corresponding to the NEW timezone!
So if you opened the app in Brazil, UTC midnight `2023-10-05` was `2023-10-04 21:00 Local`.
`toParsedDay()` format it as `"2023-10-04"`.
Wait! If we ONLY care about "An entry stays on the calendar day it was logged on", then we must NOT format local `DateTime` components if the `DateTime` was meant to be a day label!
But wait, how do we fix this without migrating the DB?
Look at `DayBoundaryCalc._logicalDayOfTotalMinutes`.
It returns `DateTime(shifted.year, shifted.month, shifted.day)`. This is a LOCAL DateTime.
Wait! What if we use `.toUtc()` everywhere for Day Labels?
No! If we look at the issue description:
"A likely recipe: 1. Log food and an activity at local time UTC-3 on two consecutive days. 2. Change the device time zone to UTC+2. 3. Open both days in the Diary."
"Expected behaviour: An entry stays on the calendar day it was logged on."
"Actual behaviour: Entries move to another day, and the day total and the listed entries disagree."

Why did the entry move?
Because `isMomentInLogicalDayMinutes` compares `momentDay` to `dayLabel`.
`momentDay` is `_logicalDayOfTotalMinutes(intake.dateTime, ...)`.
`_logicalDayOfTotalMinutes` returns `DateTime(shifted.year, shifted.month, shifted.day)`.
This creates a LOCAL DateTime for the shifted moment.
If `intake.dateTime` was logged in Brazil at 23:00. Its absolute time is 02:00 UTC.
In Germany (UTC+2), `intake.dateTime` is evaluated as 04:00 Local.
`shifted` is 04:00 Local.
`momentDay` is `DateTime(..., 6)` (the 6th).
`dayLabel` comes from `table_calendar` (e.g. the 5th).
They don't match, so the intake is NOT shown on the 5th. It is shown on the 6th.

But wait! In `getAllIntakesByDate` we iterate through all `IntakeDBO` entries.
Is there any way to know that `intake.dateTime` was originally 23:00 in Brazil?
No! `DateTime` in Dart just wraps `millisecondsSinceEpoch`. It has absolutely no knowledge of the timezone it was created in!
If it has no knowledge of the timezone, HOW could we possibly know it was the 5th?
Wait! In `DayBoundaryCalc`, they say:
"Some reporters live by a 04:00-to-04:00 day rather than the wall-clock 00:00-to-00:00 one..."
"The offset only affects which logical day an entry aggregates under. Stored timestamps remain wall-clock (i.e. DateTime.now() at the time the entry was created)."
Wait! If `IntakeDBO.dateTime` is ALWAYS stored as wall-clock, it means it is a UTC timestamp!
Since it is a UTC timestamp, it WILL shift when changing timezones!
BUT if the issue EXPECTS it to stay on the same calendar day, is there ANY workaround?
"Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST."
Wait, if it's the SAME FAMILY as #1224, maybe the issue is that it should use UTC arithmetic?
Look at `DateTime.utc` vs `DateTime`.
Memory says: "To accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."

What if `TrackedDayDBO.day` (the day label) was created by `DayBoundaryCalc.currentLogicalDay`?
```dart
  static DateTime currentLogicalDay(int? offsetHours) =>
      logicalDayOf(clock(), offsetHours);

  static DateTime logicalDayOf(DateTime moment, int? offsetHours) {
    final totalMinutes = _sanitiseHours(offsetHours) * 60;
    return _logicalDayOfTotalMinutes(moment, totalMinutes);
  }

  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
Wait! `_logicalDayOfTotalMinutes` returns a LOCAL `DateTime(shifted.year, shifted.month, shifted.day)`.
Because it is a LOCAL `DateTime`, its epoch depends on the device's timezone!
If the device is in Brazil, `DateTime(2023, 10, 5, 0)` produces epoch `X`.
If the device is in Germany, `DateTime(2023, 10, 5, 0)` produces epoch `Y`.
So a day label created in Brazil has epoch `X`.
When saved to Hive, it is saved as `X`.
When retrieved in Germany, `X` is parsed as `DateTime.fromMillisecondsSinceEpoch(X)`, which is `2023-10-05 05:00:00` Local!
And then if they call `_isDayLabel` on it:
```dart
  static bool _isDayLabel(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
```
It returns FALSE!!! Because its hour is 5, not 0!
So `DayBoundaryCalc` treats the loaded day label as a REGULAR TIMESTAMP and subtracts the offset from it!
This means `isMomentInLogicalDayMinutes` will apply the offset to the day label AGAIN!
And `TrackedDayDBO.day` (which is a day label) will have its offset subtracted again if used as a moment!
BUT `TrackedDayDBO.day` is NOT used as a moment. It is used as `trackedDay.day.toParsedDay()`.
Wait, `toParsedDay()` on `2023-10-05 05:00:00` in Germany returns `"2023-10-05"`. This works!
BUT what if we went from Germany to Brazil?
In Germany, day label was `DateTime(2023, 10, 5, 0)`. Epoch `Y`.
In Brazil, `Y` is `2023-10-04 19:00:00`.
`toParsedDay()` on this returns `"2023-10-04"`!!
So the `TrackedDayDBO` MOVES to the 4th!
AND `IntakeDBO` with timestamp 12:00 PM Germany (which is `10:00 AM UTC`) -> 07:00 AM Brazil. Still the 5th!
So `IntakeDBO` stays on the 5th, but `TrackedDayDBO` moves to the 4th!
So the 5th has listed entries, but NO day total!
This EXACTLY explains "the day total and the listed entries disagree" AND "Entries move to another day"!!

WHY does `TrackedDayDBO.day` shift?
Because `DayBoundaryCalc._logicalDayOfTotalMinutes` returns a LOCAL `DateTime` using `DateTime(shifted.year, ...)`!
AND `JsonMealImporter` returns `DateTime(y, m, d)` (Local)!
If day labels are LOCAL DateTimes, their absolute epoch shifts when you cross timezones, and they can cross midnight, changing their `.year`/`.month`/`.day`!

HOW DO WE FIX THIS?
If we construct DAY LABELS as UTC DateTimes: `DateTime.utc(year, month, day)`, their epoch corresponds to UTC midnight!
Wait! If we use UTC midnight for day labels...
If a day label is created in Germany as `DateTime.utc(2023, 10, 5)`.
When loaded in Brazil, it's `DateTime.fromMillisecondsSinceEpoch(UTC midnight)`.
In Brazil, this is `2023-10-04 21:00:00 Local`!
`toParsedDay()` (which uses local format) WILL STILL RETURN `"2023-10-04"`!!!
Because `DateFormat` formats the LOCAL components of the `DateTime`!
Wait! DateFormat formats the local components unless you pass it a UTC DateTime! But Hive returns a local DateTime (`isUtc = false`)!
So changing `DayBoundaryCalc` to return `DateTime.utc` does NOT fix `toParsedDay()` when loaded from Hive!

To fix `toParsedDay()` for a Day Label that was loaded from Hive, we need to KNOW it's a day label and get its original year/month/day.
But we can't!
UNLESS we ALWAYS use a specific formatting that ignores the timezone?
Wait, if a `DateTime` was created as UTC midnight `2023-10-05 00:00:00 UTC`, its epoch is `E`.
If we read `E` in ANY timezone, and we want to recover `"2023-10-05"`.
We can just convert it to UTC! `DateTime.fromMillisecondsSinceEpoch(E, isUtc: true)`!
Then it becomes `2023-10-05 00:00:00 UTC`.
Then DateFormat returns `"2023-10-05"`!
BUT wait! What if it was created as LOCAL midnight `2023-10-05 00:00:00 Local` in Germany?
Its epoch is `2023-10-04 22:00:00 UTC`.
If we read this and convert to UTC, we get `"2023-10-04"`! Which is WRONG! We want `"2023-10-05"`!

This means we CANNOT recover the original string from just the epoch! We have LOST the information!
Wait! If the only place `toParsedDay()` is used is for Hive string keys, why are we using it on `TrackedDayDBO.day`?
Wait! In `TrackedDayDBO`, we have `DateTime day;`.
What if we DO NOT use `TrackedDayDBO.day.toParsedDay()` to save it?
When we retrieve it, we use `getTrackedDay(day)`. `day` is a fresh UI day label (e.g. UTC midnight).
It loads the `TrackedDayDBO`.
Then when we save it, why don't we save it using the fresh UI day label instead of `trackedDayDBO.day`?
Look at `TrackedDayDataSource.saveTrackedDay`:
```dart
  Future<void> saveTrackedDay(TrackedDayDBO trackedDayDBO) async {
    log.fine('Updating tracked day in db');
    await _trackedDayBox.put(trackedDayDBO.day.toParsedDay(), trackedDayDBO);
  }
```
If we change it to NOT rely on `trackedDayDBO.day`, but we still need a key. Where does the key come from?
Wait! Hive Objects DO have their original key! `trackedDayDBO.key` is the string key!
```dart
  Future<void> saveTrackedDay(TrackedDayDBO trackedDayDBO) async {
    log.fine('Updating tracked day in db');
    final key = trackedDayDBO.key ?? trackedDayDBO.day.toParsedDay();
    await _trackedDayBox.put(key, trackedDayDBO);
  }
```
If we use `trackedDayDBO.key`, it uses the EXACT same string key it was loaded from!!
This would prevent it from "moving" when updated!
But wait, what about `WeightLogDataSource`?
```dart
  Future<void> saveEntry(WeightLogDBO entry) async {
    await _weightLogBox.put(entry.date.toParsedDay(), entry);
  }
```
If we use `entry.key ?? entry.date.toParsedDay()`!

BUT wait! If `TrackedDayDBO.day` is rendered in the UI?
It's NOT rendered in the UI! The calendar passes its OWN `day` to query.
Wait, `TrackedDayDBO.day` IS used anywhere else?
Let's search for `trackedDay.day`:
`lib/features/diary/presentation/bloc/diary_bloc.dart`:
```dart
      final trackedDaysMap = {
        for (var trackedDay in trackedDays)
          trackedDay.day.toParsedDay(): trackedDay,
      };
```
Ah! `getTrackedDaysByRange` returns a LIST of `TrackedDayDBO`.
Then `DiaryBloc` groups them into a Map using `trackedDay.day.toParsedDay()`!
If `trackedDay.day.toParsedDay()` returns `"2023-10-04"` in Brazil, it will group it under `"2023-10-04"`!
Then the UI calendar for `"2023-10-05"` will look up `"2023-10-05"` and find NOTHING!
So the Day Totals DISAGREE because they are grouped by `trackedDay.day.toParsedDay()`!
