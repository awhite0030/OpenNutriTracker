Yes! `day` is passed into `ActivityDetailBloc`, and `QuickAddActivityBottomSheet` uses `widget.day` (which comes from the calendar!).
So `UserActivityEntity.date` is ALSO a Day Label (UTC midnight)!

If I apply my fix, BOTH Diary-logged Intakes AND Diary-logged Activities WILL STICK to the calendar day they were logged on!
And `TrackedDayDBO` will NOT DUPLICATE!
This perfectly resolves the issue described in the PR!

Let me refine the plan:
1. Update `extensions.dart`: `toParsedDay()` to use `toUtc()` if the date is exactly a UTC midnight.
2. Update `DayBoundaryCalc`:
   a. Change `_logicalDayOfTotalMinutes` to return `DateTime.utc(shifted.year, shifted.month, shifted.day)`.
   b. Change `_isDayLabel` to also check if it's a UTC midnight (`millisecondsSinceEpoch % 86400000 == 0`).
   c. Change `isMomentInLogicalDayMinutes` to safely compare UTC properties if the moment/dayLabel are UTC midnights.

Let's double check if there's any other place `DayBoundaryCalc` compares days.
`isSameLogicalDayMinutes` is good (because `logicalDayOfMinutes` will return UTC).
`isSameLogicalDay` calls `logicalDayOf` which delegates to `logicalDayOfMinutes`. Good.
`currentLogicalDayLabel` calls `currentLogicalDayMinutes`. Good.

One more detail: memory rule:
"In Dart, to accurately calculate the difference in calendar days between two local DateTime objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
Wait, `DayBoundaryCalc` currently returns `DateTime(...)` which is a LOCAL DateTime.
If the developers wanted to use UTC midnights, they would do `DateTime.utc(...)` instead of `DateTime(...)`.
This memory hint is literally telling me to construct `DateTime.utc`!

I'll request a plan review.
