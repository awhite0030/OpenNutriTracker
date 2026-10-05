Wait, look at `DayBoundaryCalc._isDayLabel(DateTime value)`!
```dart
  static bool _isDayLabel(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
```
If `IntakeDBO.dateTime` is EXACTLY midnight (because some importers or old versions might have set it to exactly midnight?), then `_isDayLabel` returns true.
But if it was a real timestamp, it returns false.

Wait! If we want to solve "An entry stays on the calendar day it was logged on", maybe the issue is that we SHOULD NOT store `IntakeDBO.dateTime` as local time, or we should format dates using their UTC components?
If we use `DateTime.utc(dt.year, dt.month, dt.day)` everywhere?
No, the problem is that `TrackedDayDBO.day` ALSO shifts!
Wait, if `TrackedDayDBO.day` was logged as UTC midnight (`DateTime.utc(2023, 10, 5)`), and it shifts to `2023-10-04 21:00 Local` in Brazil.
If we call `toParsedDay()` on it, it returns `2023-10-04`.
This means if you travel to Brazil, your 5th's `TrackedDayDBO` is mapped to `2023-10-04` when you overwrite it!
BUT, when you query it via `getTrackedDay(day)`, you pass `DateTime.utc(2023, 10, 5)`.
`day.toParsedDay()` returns `2023-10-05`.
So it looks for key `"2023-10-05"`.
If the key `"2023-10-05"` exists (from Germany), it loads it.
But then `TrackedDayDBO.day` inside it is `2023-10-04 21:00 Local`.
When it saves it back: `_trackedDayBox.put(trackedDayDBO.day.toParsedDay(), trackedDayDBO);`
It saves it to `"2023-10-04"`!!
So it effectively DUPLICATES the tracked day to the 4th, and the 5th no longer gets updated!
This is a HUGE bug!

So how do we fix `TrackedDayDBO.day` shifting?
We can change `toParsedDay` to use the UTC components!
If we change `toParsedDay` to use `.toUtc()`? No!
Wait. If `TrackedDayDBO.day` was `2023-10-05 00:00 UTC` (created in Germany).
In Brazil it's `2023-10-04 21:00 Local`.
If we call `.year`, it's 2023. `.month` is 10. `.day` is 4.
If we want it to be 5, we MUST call it as UTC! Because its absolute epoch is UTC midnight on the 5th.
Wait! What if the `TrackedDayDBO.day` was created in Brazil using LOCAL midnight?
`JsonMealImporter` uses `DateTime(y, m, d)` (local midnight).
If it was created as local midnight in Brazil, it's `2023-10-05 00:00 Local` in Brazil.
Its epoch is `1696474800000`.
In UTC, this epoch is `2023-10-05 03:00:00 UTC`.
In Germany, this epoch is `2023-10-05 05:00:00 Local`.
If we format it as local in Germany, it's `2023-10-05`.
If we format it as UTC, it's `2023-10-05`.
So for BOTH UTC midnight AND Local midnight, converting to UTC OR keeping Local will keep it on the 5th?
Let's check!
