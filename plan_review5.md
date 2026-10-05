Wait, let's read the issue description again.
"After a flight from Brazil to Germany (UTC-3 -> UTC+2), one day's calorie total no longer matched the sum of its entries, and activities that had been logged on different days appeared on the same day."
"A likely recipe: 1. Log food and an activity at local time UTC-3 on two consecutive days. 2. Change the device time zone to UTC+2. 3. Open both days in the Diary."
"Expected behaviour: An entry stays on the calendar day it was logged on."
"Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST."

In #1224 and #1207, the bug was caused by using `Duration(days: 1)`. When crossing DST, a day is 23 or 25 hours, so adding 24 hours causes the date to shift unexpectedly.
But here, it says the issue is "24-hour spans vs calendar days around DST".
Wait, if it's "the same family", maybe they are currently doing something with `DateTime` that depends on local timezone.
Wait, `toParsedDay` uses `DateFormat('yyyy-MM-dd')`. It formats the *local* date.
If `TrackedDayDBO.day` is `2023-10-05 00:00:00 UTC`, its local date in Brazil is `2023-10-04`.
If `TrackedDayDBO.day` is `2023-10-05 00:00:00 Local` (in Brazil), its local date in Germany is `2023-10-05 05:00:00`, which is still `2023-10-05`.
But wait! If they log at 23:00 Local in Brazil, it's `2023-10-06 04:00:00 Local` in Germany.
So an entry logged on the 5th moves to the 6th.

But wait, if we change `toParsedDay` to convert the `DateTime` to UTC first?
Wait, if `TrackedDayDBO.day` was logged as Local midnight in Brazil (`2023-10-05 00:00:00 UTC-3`).
Its epoch is `1696474800000`.
In UTC, this epoch is `2023-10-05 03:00:00 UTC`.
If we format it as UTC, it's `2023-10-05`.
What if it was logged as Local midnight in Germany (`2023-10-05 00:00:00 UTC+2`)?
Its epoch is `1696456800000`.
In UTC, this epoch is `2023-10-04 22:00:00 UTC`.
If we format it as UTC, it becomes `2023-10-04`!
So formatting as UTC doesn't work for Germany!

Wait. When we fetch from Hive, `DateTime` objects come back with `isUtc == false` (local).
How do we know if it was a "Day Label" (midnight)?
In `DayBoundaryCalc`, they use `_isDayLabel(DateTime value)`:
```dart
  static bool _isDayLabel(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
```
But wait! If `TrackedDayDBO.day` was saved as `2023-10-05 00:00:00` in Brazil, when loaded in Germany, it's `2023-10-05 05:00:00`.
Then `_isDayLabel` will return `FALSE` because `hour == 5`!
So `DayBoundaryCalc` will no longer treat it as a Day Label! It will apply the logical boundary offset!
Wait, `TrackedDayDBO.day` is NOT checked with `_isDayLabel`. It is the `intake.dateTime` that might be checked with `_isDayLabel` if it's a day label.
Wait, `table_calendar` produces `DateTime.utc(y, m, d)`.
So `TrackedDayDBO.day` is actually created from `DateTime.utc(y, m, d)`?
Let's trace where `TrackedDayDBO` is created.
