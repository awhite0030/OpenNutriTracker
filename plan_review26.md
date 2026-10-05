Let me write the plan.
Wait, if the user explicitly created the memory hint, I must follow it.
The memory hint says:
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
"In Dart, use calendar-day arithmetic via DateTime constructors (e.g., DateTime(date.year, date.month, date.day - 1)) instead of Duration subtraction (date.subtract(Duration(days: 1))) for manipulating full calendar days, as Duration uses wall-clock hours and may fail across DST boundaries."

This hint is about "difference in calendar days" and "manipulating full calendar days".
Where are we calculating the difference in calendar days?
I searched for `inDays` and found it in `user_entity.dart` (age calculation), `weight_trend_chart.dart`, `weight_history_screen.dart`, `trends_bloc.dart`, `trends_calc.dart`.
Wait, none of these are related to `IntakeDBO` or `TrackedDayDBO` directly!
BUT wait! Is it possible that "Entries move to another day, and the day total and the listed entries disagree" is caused by a bug in calculating differences in calendar days?
Let's check `lib/features/trends` and `lib/features/diary`.
Does `DiaryBloc` calculate difference in days? No, it uses `.toParsedDay()`.

Wait, what if the bug is NOT in `DayBoundaryCalc`?
What if the bug is in how `TrackedDayDBO`s are grouped in `DiaryBloc`?
In `DiaryBloc`, `trackedDay.day.toParsedDay()` groups them.
If `trackedDay.day` is `2023-10-04 21:00 Local`, `toParsedDay` returns `"2023-10-04"`.
If the user traveled to Germany, the SAME `TrackedDayDBO` loaded from Hive in Germany will evaluate to `2023-10-05 05:00 Local` (because its epoch is UTC midnight), so `toParsedDay` returns `"2023-10-05"`.
So the SAME `TrackedDayDBO` moves to the 4th in Brazil, but stays on the 5th in Germany!
Wait, but if `TrackedDayDBO` moves, its key in Hive is STILL `"2023-10-05"`.
So when we fetch `getTrackedDaysByRange`, it returns all `TrackedDayDBO`s.
Then `DiaryBloc` groups them by `toParsedDay()`.
So the `"2023-10-05"` key in Hive gets grouped under `"2023-10-04"` in Brazil!
And when `DiaryTableCalendar` looks up `"2023-10-05"` (because the calendar passes UTC midnight `2023-10-05` and formats it as `"2023-10-05"`), it finds NOTHING!
So the day total for the 5th is EMPTY in Brazil!
THIS IS THE DISAGREEMENT!
How can we fix `trackedDay.day.toParsedDay()` so that it returns `"2023-10-05"` even in Brazil?
If we know `trackedDay.day` was a UTC midnight, we can just use its UTC properties!
But `TrackedDayDBO.day` might be a Local midnight (from `JsonMealImporter`).
BUT wait! If it's a Local midnight, its epoch is not divisible by 86400000.
We can check if it is divisible by 86400000!
Wait, what if we just change how ALL dates are stored and read? No, can't change DB.
Wait! What if we change `toParsedDay`?
```dart
extension FormatString on DateTime {
  String toParsedDay() {
    // If it is an exact UTC midnight, format its UTC properties.
    if (millisecondsSinceEpoch % 86400000 == 0) {
      return DateFormat('yyyy-MM-dd').format(toUtc());
    }
    return DateFormat('yyyy-MM-dd').format(this);
  }
}
```
If we do this, `trackedDay.day.toParsedDay()` for a UTC midnight loaded in Brazil will correctly return `"2023-10-05"`!
This fixes `TrackedDayDBO` mapping in `DiaryBloc`!
AND it fixes `TrackedDayDataSource.saveTrackedDay` overwriting the wrong key!
AND it fixes `WeightLogDataSource.saveEntry`!

BUT wait! Does this fix `IntakeDBO` moving?
If an intake was logged at 23:00 Brazil (`DateTime.now()`).
In Germany, it evaluates to 04:00 next day.
If `isMomentInLogicalDayMinutes` compares it, it will STILL evaluate to the 6th.
So `IntakeDBO` will STILL move to the 6th!
Did the developers want us to fix `IntakeDBO` moving?
"Entries move to another day... An entry stays on the calendar day it was logged on."
Yes!
But how can we fix `IntakeDBO` moving if we don't know the timezone it was logged in?
Wait! If we convert to UTC...
`DateTime.utc(d1.year, d1.month, d1.day)`
Is there ANY way to avoid timezone shifts?
What if the issue is NOT that we change timezone?
Wait, "After a flight from Brazil to Germany (UTC−3 → UTC+2), one day's calorie total no longer matched the sum of its entries, and activities that had been logged on different days appeared on the same day."
Yes, timezone is changing!

Wait, is there ANY place where `IntakeDBO` calendar day is stored?
`IntakeDBO` has NO OTHER FIELDS except `dateTime`.
If it only has `dateTime`, and it's a `DateTime` stored in Hive as an epoch.
There is LITERALLY NO WAY to recover the original timezone!
So we CANNOT keep an exact timestamp on its original calendar day!
UNLESS we store the timezone, or we store the calendar day explicitly!
Since we can't change the DB schema (without a migration script, which I can't easily write and test without breaking things), is there a simpler way?
Wait! HiveCE's `DateTimeAdapter` stores `DateTime` as a 64-bit integer.
But wait! If `IntakeDBO` was logged using `table_calendar`, its `dateTime` is a UTC midnight!
And if it's a UTC midnight, its epoch is divisible by 86400000.
If they logged it from the Diary, it IS a UTC midnight!
If it's a UTC midnight, it currently fails `_isDayLabel` in the new timezone (because `.hour != 0`).
If we fix `_isDayLabel`, then intakes logged from the Diary will be recognized as Day Labels!
If they are Day Labels, `isMomentInLogicalDayMinutes` uses them DIRECTLY without boundary shifting!
Wait, but if it uses them directly, `momentDay.day == dayLabel.day` will STILL fail if we don't use `.toUtc()`!
Let's see: `isMomentInLogicalDayMinutes` does:
```dart
    final momentDay = _isDayLabel(moment)
        ? moment
        : logicalDayOfMinutes(moment, offsetTotalMinutes);
    return momentDay.year == dayLabel.year &&
        momentDay.month == dayLabel.month &&
        momentDay.day == dayLabel.day;
```
If we fix it to:
```dart
  static bool _isDayLabel(DateTime value) {
    return (value.hour == 0 && value.minute == 0 && value.second == 0 && value.millisecond == 0 && value.microsecond == 0) ||
           (value.millisecondsSinceEpoch % 86400000 == 0);
  }

  static bool isMomentInLogicalDayMinutes(...) {
    DateTime momentDay = _isDayLabel(moment)
        ? moment
        : logicalDayOfMinutes(moment, offsetTotalMinutes);

    // To compare calendar days correctly, we must convert Day Labels to their canonical UTC form if they are UTC midnights.
    if (momentDay.millisecondsSinceEpoch % 86400000 == 0) momentDay = momentDay.toUtc();
    final dl = dayLabel.millisecondsSinceEpoch % 86400000 == 0 ? dayLabel.toUtc() : dayLabel;

    return momentDay.year == dl.year && ...
```
If we do this, Intakes logged from the Diary WILL stay on their original day!
BUT what about Intakes logged from the Home Page (using `DateTime.now()`)?
If they were logged with `DateTime.now()`, their epoch is NOT divisible by 86400000.
They WILL shift. Is it possible to prevent them from shifting?
No! Because they are absolute moments. A moment at 23:00 in Brazil IS 04:00 the next day in Germany.
It's logically impossible to prevent it without the original timezone.
Wait, if it's logically impossible, maybe the "Expected behaviour: An entry stays on the calendar day it was logged on" was ONLY referring to Diary-logged entries?
Because Diary-logged entries are exactly the ones that fail `_isDayLabel` and get shifted!
And maybe the Day Totals mismatch because `TrackedDayDBO` fails `toParsedDay()`!
