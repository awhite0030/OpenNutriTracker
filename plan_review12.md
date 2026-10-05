Let's check `toParsedDay` again.
```dart
extension FormatString on DateTime {
  String toParsedDay() => DateFormat('yyyy-MM-dd').format(this);
}
```
If we don't want it to shift when it was a UTC midnight loaded from Hive...
Wait! If it was UTC midnight `2023-10-05 00:00:00Z` loaded from Hive in Brazil, it's `2023-10-04 21:00:00 Local`.
Wait! If it's a day label, it ALWAYS represents a specific calendar day.
But wait! If they log food and an activity at UTC-3 on the 5th (let's say at 12:00 PM).
`IntakeDBO.dateTime` is `2023-10-05 12:00:00 Local` (epoch = 15:00 UTC).
They change timezone to UTC+2.
`IntakeDBO.dateTime` becomes `2023-10-05 17:00:00 Local`.
Since 17:00 is on the SAME day, `toParsedDay()` (if applied) would be the same.
But wait! What if they logged it at 23:00 Local (UTC-3)?
Epoch is 02:00 UTC next day.
In Germany (UTC+2), it is 04:00 Local next day.
So it moved to the next day!

How to fix "An entry stays on the calendar day it was logged on"?
If the `DateTime` was logged as an epoch, it inherently shifts its local hour.
To prevent it from shifting its CALENDAR DAY, we need to know the original offset, OR we just shouldn't use absolute epochs!
But we CANNOT change the data type of `DateTime` in `IntakeDBO` because Hive would fail to read old data without a migration!
Wait! Can we migrate the data?
"Work fully autonomously: NEVER ask questions... Reproduce the problem with a minimal, focused case before changing anything."
Wait, if I change `toParsedDay` to output the exact string, it won't fix `IntakeDBO.dateTime`.
But wait! "Entries move to another day, and the day total and the listed entries disagree."
What if we change how `DayBoundaryCalc` determines the logical day?
If we use `.toUtc()`? No.
