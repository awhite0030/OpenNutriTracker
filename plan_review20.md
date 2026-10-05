Wait, this implies that `.difference(..).inDays` is flawed.
But how does that fix the timezone crossing bug for `IntakeDBO` and `TrackedDayDBO`?
The issue explicitly states:
"A likely recipe: 1. Log food and an activity at local time UTC-3 on two consecutive days. 2. Change the device time zone to UTC+2. 3. Open both days in the Diary."
"Expected behaviour: An entry stays on the calendar day it was logged on."
"Actual behaviour: Entries move to another day, and the day total and the listed entries disagree."

If the ONLY fix we can do is what is strictly asked by the bug.
If `IntakeDBO.dateTime` is a timestamp, and we want it to stay on the same calendar day...
Wait, if it was stored as local time `23:00` in Brazil. In Germany it is `04:00` next day.
There is NO WAY to know it was originally on the 5th, UNLESS the `TrackedDayDBO` is the source of truth, or we parse its string representation? No, `IntakeDBO` is independent.
Wait! What if we DO NOT parse the absolute moment using `logicalDayOfMinutes` for rendering?
No, the UI uses `getAllIntakesByDate(table_calendar_day)`.
What if `DayBoundaryCalc` IS the problem?
Wait, the memory hint says:
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
AND
"In Dart, use calendar-day arithmetic via DateTime constructors (e.g., DateTime(date.year, date.month, date.day - 1)) instead of Duration subtraction (date.subtract(Duration(days: 1))) for manipulating full calendar days, as Duration uses wall-clock hours and may fail across DST boundaries."

Look at `DayBoundaryCalc`:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
Wait! `moment.subtract(Duration(minutes: totalMinutes))` is fine because `totalMinutes` is small.
BUT `return DateTime(shifted.year, shifted.month, shifted.day)` creates a LOCAL DateTime.
And `_isDayLabel(DateTime value)` checks `value.hour == 0 && ...` (which fails if the local timezone changed since it was loaded from Hive!).

If we change `toParsedDay` to output the correct string regardless of timezone offset...
How? We CANNOT!

Wait! I missed something!
"An entry stays on the calendar day it was logged on."
How is this possible for absolute timestamps?
What if `IntakeDBO.dateTime` was NEVER an absolute timestamp?
Let's check `AddMealScreenArguments`.
