Look at Memory again:
"In Dart, to accurately calculate the difference in calendar days between two local `DateTime` objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."

Could it be that `toParsedDay` should just format the date string, and the issue is actually in how `DayBoundaryCalc` handles dates?
Wait, if `TrackedDayDBO.day` shifts, why does it shift? Because the epoch is absolute.
If they log food and an activity at UTC-3, and then travel to UTC+2.
"Entries move to another day, and the day total and the listed entries disagree."
If we look at `IntakeDBO.dateTime`, it is a `DateTime` containing an absolute epoch.
When `getAllIntakesByDate` is called, it filters by:
`DayBoundaryCalc.isMomentInLogicalDayMinutes(dayLabel, intake.dateTime, totalMinutes)`

Let's look at `DayBoundaryCalc.isMomentInLogicalDayMinutes`:
```dart
  static bool isMomentInLogicalDayMinutes(
    DateTime dayLabel,
    DateTime moment,
    int? offsetTotalMinutes,
  ) {
    final momentDay = _isDayLabel(moment)
        ? moment
        : logicalDayOfMinutes(moment, offsetTotalMinutes);
    return momentDay.year == dayLabel.year &&
        momentDay.month == dayLabel.month &&
        momentDay.day == dayLabel.day;
  }
```
If `intake.dateTime` was recorded at 23:00 in Brazil (UTC-3), it was 02:00 UTC next day.
When loaded in Germany (UTC+2), `intake.dateTime` is a local `DateTime` corresponding to 04:00 next day.
`logicalDayOfMinutes(moment, offsetTotalMinutes)` will return `momentDay` as the 6th (assuming offset is 0).
So it will match `dayLabel` = 6th!
So the intake "moves" to the 6th!
BUT wait! Is it possible to stop `IntakeDBO.dateTime` from moving?
No! `IntakeDBO.dateTime` represents an absolute moment. By definition, a moment at 23:00 UTC-3 IS 04:00 UTC+2 on the next day.
If the expected behavior is "An entry stays on the calendar day it was logged on", then `IntakeDBO` should have stored the local calendar day it was logged on. But it didn't! It only stores `dateTime`!
If it only stores `dateTime`, how can we fix it without schema changes?
Wait, wait.
"Entries move to another day, and the day total and the listed entries disagree."
Why do they disagree?
Because `TrackedDayDBO` is keyed by `toParsedDay()`.
Wait, `TrackedDayDBO` was keyed by `2023-10-05` when logged in Brazil.
In Germany, if we open the Diary for `2023-10-05`, it queries `_trackedDayBox.get("2023-10-05")`.
It successfully loads the `TrackedDayDBO` which has the calories from that intake!
BUT `getAllIntakesByDate(2023-10-05)` checks `isMomentInLogicalDayMinutes`, and since the intake shifted to the 6th, it does NOT return the intake!
So the 5th shows the calories in the total, but no intake in the list!
And the 6th shows the intake in the list, but its `TrackedDayDBO` doesn't have the calories!
This EXACTLY explains the disagreement!

How do we fix this?
If we cannot know the original timezone, we CANNOT fix `IntakeDBO.dateTime` to perfectly match the original local day.
Wait, is there any other field?
Let's check `IntakeDBO`.
