Wait, `TrackedDayDBO.day` is NOT created by `table_calendar`. It is created by `addTrackedDayUsecase`.
Where does `day` come from?
In `DiaryBloc`, `currentDay = DayBoundaryCalc.currentLogicalDayMinutes(config.dayStartOffsetTotalMinutes);`
`currentDay` is passed to `getTrackedDaysByRange`.
Wait, what is `DayBoundaryCalc.currentLogicalDayMinutes`?
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
`DateTime(...)` creates a LOCAL DateTime!
So `currentDay` is LOCAL midnight!
If it's LOCAL midnight, then `TrackedDayDBO.day` is LOCAL midnight!
If `TrackedDayDBO.day` is local midnight, then its epoch is local midnight.
In Brazil, Local midnight is 03:00 UTC.
If it is stored, its epoch is `1696474800000`.
When retrieved in Brazil, it's STILL `2023-10-05 00:00:00 Local`.
So `toParsedDay()` returns `"2023-10-05"`. This works perfectly as long as you don't travel!

But when you travel to Germany (UTC+2):
The epoch `1696474800000` is read back.
In Germany, this epoch corresponds to `2023-10-05 05:00:00 Local`.
Wait! If it is `05:00:00 Local`, `toParsedDay()` will return `"2023-10-05"`!!
So it STILL works in Germany!!
Wait... if `toParsedDay()` still returns `"2023-10-05"`, why did the day totals mismatch??
Ah! "Entries move to another day" => the `IntakeDBO` entries moved!
Did `TrackedDayDBO` move?
Wait... if `TrackedDayDBO.day` was logged in Germany!
If it was logged in Germany, it's `DateTime(2023, 10, 5, 0)` in Germany.
Epoch: `1696456800000` (which is `2023-10-04 22:00:00 UTC`).
When the user travels to Brazil (UTC-3), this epoch corresponds to `2023-10-04 19:00:00 Local` in Brazil!
Then `toParsedDay()` returns `"2023-10-04"`!!!
So if they log something in Germany and travel to Brazil, their `TrackedDayDBO` MOVES to the 4th!
And their `WeightLog` MOVES to the 4th!
And if they open the 5th in the calendar, they won't see their totals!
THIS is the exact bug described:
"After a flight from Brazil to Germany (UTC-3 -> UTC+2)..."
Wait, if they went from Brazil to Germany, the epoch was `2023-10-05 00:00 Brazil` -> `2023-10-05 05:00 Germany`. The day is STILL the 5th!
But what if they logged it at 23:00 in Brazil?
No, `TrackedDayDBO.day` is always midnight (created via `DateTime(y, m, d)`).
Wait! If they flew from Brazil to Germany, then logging in Brazil created a `2023-10-05 00:00` Local Brazil.
In Germany, it becomes `05:00`. So `TrackedDayDBO` stays on the 5th!
BUT what about `IntakeDBO`?
If they logged an intake at 23:00 in Brazil.
In Germany, it becomes 04:00 on the 6th!
So the intake moves to the 6th, but `TrackedDayDBO` stays on the 5th!
So the 5th has the total (from Brazil), but the 6th has the intake!
They don't match!

So how do we fix `IntakeDBO` moving?
And how do we fix `TrackedDayDBO` moving (if they flew from Germany to Brazil)?
To fix BOTH, we must format dates based on their original calendar day!
But we CAN'T! `DateTime` doesn't store the original offset!
Wait! Is it possible to CHANGE how we store calendar dates?
If we cannot change the database, how can we fix it?
Wait! In #1224 and #1207 memory rule:
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays."
Wait! If the ONLY problem is how we query intakes?
No, if `IntakeDBO` moves to the 6th, it's because it's a REAL timestamp. It ACTUALLY occurred on the 6th in Germany time.
But the user EXPECTS it to stay on the 5th!
"An entry stays on the calendar day it was logged on."
If we want it to stay on the calendar day it was logged on, why did they use `DateTime.now()` for `IntakeDBO.dateTime` instead of just the day label?
Because they want to sort them by time added!
If they want to sort by time added, and also stay on the same calendar day...
Wait, if we can't get the original timezone, maybe we can RECOVER the original calendar day from `IntakeDBO`?
No, `IntakeDBO` only has `dateTime`.
Wait! Does `IntakeDBO` have a relationship with `TrackedDayDBO`? No, they are independent.
BUT wait! `toParsedDay()` formatting.
Is there any PR or rule that tells me what to do?
"In Dart, use calendar-day arithmetic via DateTime constructors... instead of Duration subtraction"

Wait! The issue says:
"A likely recipe: 1. Log food and an activity at local time UTC-3 on two consecutive days. 2. Change the device time zone to UTC+2. 3. Open both days in the Diary."
"Expected behaviour: An entry stays on the calendar day it was logged on."
"Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST."

Wait, what if the issue is NOT about `IntakeDBO` moving, but about `toParsedDay` producing different days because we used `Duration` somewhere?!
Let's check `toParsedDay`. No, it uses `DateFormat`.
Let's check `DayBoundaryCalc`.
