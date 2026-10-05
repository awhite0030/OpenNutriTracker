`widget.mealDetailBloc.addIntake` passes `widget.day`!
Where does `MealDetailBottomSheet` get `widget.day`?
If you launch it from Home page, `widget.day` is `DateTime.now()`!
Wait! If it is `DateTime.now()`, it is NOT a Day Label! It is a real timestamp!
And the issue is: "An entry stays on the calendar day it was logged on."
If it was logged with `DateTime.now()`, it is a real timestamp.
Its epoch corresponds to the exact moment it was logged.
If you travel, the local hour of that absolute moment changes!
So if you logged at 23:00 Brazil, it is 04:00 Germany on the NEXT DAY.
So `IntakeDBO.dateTime` shifted to the NEXT DAY!
If we want it to stay on the SAME DAY, we must NOT use the local hour evaluated in Germany!
But how can we evaluate its local hour in Brazil, if we are in Germany?
We CANNOT! `DateTime` doesn't know it was in Brazil!
So if we cannot evaluate it in Brazil, how can we fix "An entry stays on the calendar day it was logged on"?
We HAVE TO format it correctly in `toParsedDay()`? No, `toParsedDay` is not used for `IntakeDBO.dateTime`!
`IntakeDBO.dateTime` is compared using `isMomentInLogicalDayMinutes`!

Wait, `table_calendar` produces `DateTime.utc(y, m, d)`.
This is passed to `dayLabel` in `isMomentInLogicalDayMinutes`.
`logicalDayOfMinutes(intake.dateTime, offset)` returns a LOCAL DateTime!
If `intake.dateTime` was `DateTime.now()` (23:00 Brazil), `logicalDayOfMinutes` returns the 6th in Germany.
So it doesn't match the 5th!
If we change `logicalDayOfMinutes` to return UTC? No, the problem is `intake.dateTime` evaluating to the 6th.
Can we fix `intake.dateTime` evaluating to the 6th?
NO, because it is an absolute epoch, so it represents 04:00 in Germany. 04:00 in Germany IS on the 6th!

Wait, if we can't fix `intake.dateTime` evaluating to the 6th, what DO they mean by "Probably the same family as #1224 and #1207"?
In #1224, using `DateTime(date.year, date.month, date.day - 1)` prevents bugs because `Duration(days: 1)` is 24 hours, which crosses DST boundaries incorrectly (23 or 25 hours).
Wait! What if we change the way `IntakeDBO` stores `dateTime`?
"Work fully autonomously: NEVER ask questions... Fix the root cause with the smallest focused change. No unrelated refactors."
If we look at `DayBoundaryCalc._logicalDayOfTotalMinutes`:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
If we change it to use `.toUtc()`?
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime.utc(shifted.year, shifted.month, shifted.day);
  }
```
If we do this, `currentLogicalDayMinutes` returns a UTC midnight!
And `isMomentInLogicalDayMinutes` will compare `momentDay` (UTC midnight) to `dayLabel` (UTC midnight from table_calendar).
This STILL evaluates `shifted.year`/`.month`/`.day` using the device's CURRENT timezone (because `shifted` is local)!
So an intake at 23:00 Brazil WILL STILL be 04:00 Germany, and WILL STILL evaluate to the 6th!
BUT wait! What if `IntakeDBO.dateTime` was logged as `DateTime.utc(y, m, d)` (from Diary)?
If it was logged from Diary, `IntakeDBO.dateTime` is a Day Label!
`_isDayLabel(moment)` will be called!
If `_isDayLabel` returns TRUE, it doesn't shift it, it just uses `moment`!
But wait, if `moment` is a Day Label created as `DateTime.utc(y, m, d)`, its epoch is UTC midnight.
In Brazil, it is loaded as `2023-10-04 21:00 Local`.
`_isDayLabel` checks `.hour == 0`. It returns FALSE!
Then `_logicalDayOfTotalMinutes` subtracts the offset from `21:00`, and returns `DateTime(..., 4)` (the 4th).
So `isMomentInLogicalDayMinutes` compares the 4th to `dayLabel` (the 5th). They don't match!
So an intake logged from the DIARY moves to the 4th!
THIS is a HUGE bug! Intakes logged from the Diary are supposed to be Day Labels, but they fail `_isDayLabel` when traveling, and get shifted!

If we fix `_isDayLabel` to correctly identify UTC midnights:
```dart
  static bool _isDayLabel(DateTime value) =>
      (value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0) || (value.millisecondsSinceEpoch % 86400000 == 0);
```
Then `IntakeDBO` logged from the Diary WILL STAY ON THE 5TH!
Because `_isDayLabel` returns TRUE, so `momentDay = moment`.
`moment` is `2023-10-04 21:00 Local`.
Wait! `momentDay.day` is 4!
But `dayLabel.day` is 5 (because `table_calendar` returns UTC, and `.day` on UTC is 5)!
So `momentDay.day == dayLabel.day` (4 == 5) is FALSE!
It STILL doesn't match!

How can we make `momentDay` match `dayLabel`?
If `momentDay` is `1696464000000` (UTC midnight), its `.day` is 4 in Brazil, but 5 in UTC!
If we change `isMomentInLogicalDayMinutes` to compare UTC properties?
```dart
  static bool isSameLogicalDayMinutes(
...
    final utcMomentDay = DateTime.utc(momentDay.year, momentDay.month, momentDay.day);
```
No, `momentDay.year` is local! We want the original year/month/day.
Since `DateTime` in Dart doesn't have a way to force UTC properties if `isUtc` is false... EXCEPT by calling `.toUtc()`!
If we call `.toUtc()` on `1696464000000`, we get `2023-10-05 00:00:00 UTC`.
Then its `.day` is 5!
So if we call `.toUtc()` on BOTH `momentDay` and `dayLabel` before comparing?
```dart
  static bool isMomentInLogicalDayMinutes(
    DateTime dayLabel,
    DateTime moment,
    int? offsetTotalMinutes,
  ) {
    DateTime momentDay = _isDayLabel(moment)
        ? moment
        : logicalDayOfMinutes(moment, offsetTotalMinutes);

    momentDay = momentDay.isUtc ? momentDay : momentDay.toUtc();
    final labelUtc = dayLabel.isUtc ? dayLabel : dayLabel.toUtc();

    return momentDay.year == labelUtc.year &&
        momentDay.month == labelUtc.month &&
        momentDay.day == labelUtc.day;
  }
```
Wait! If `momentDay` is `DateTime(shifted.year, shifted.month, shifted.day)` (Local midnight).
If we call `.toUtc()` on a Local midnight, we get a UTC time that might be the previous day!
Example: `2023-10-05 00:00:00 Local` in Germany (UTC+2) -> `2023-10-04 22:00:00 UTC`.
Then its `.day` is 4!
So `.toUtc()` on Local midnights RUINS them!

THIS is exactly why the memory says:
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
They convert local `DateTime` to UTC by doing `DateTime.utc(d1.year, d1.month, d1.day)`!
This takes the LOCAL year/month/day and creates a UTC midnight!
THIS IS THE SECRET KEY!!
If we do `DateTime.utc(momentDay.year, momentDay.month, momentDay.day)` we preserve the LOCAL calendar date, but avoid DST bugs when doing arithmetic!
Wait... but if we want to fix the timezone crossing bug, `momentDay.year` ALREADY changed!
If `momentDay` is `2023-10-04 21:00 Local`, its `.day` is 4. `DateTime.utc(y, m, d)` makes it `2023-10-04 UTC`.
It DOES NOT fix the timezone crossing bug!
