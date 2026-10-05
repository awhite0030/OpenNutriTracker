Wow!
If a `TrackedDayDBO.day` was created using `DateTime(2023, 10, 5, 0)` in Germany.
When read in Brazil, both `.toUtc()` AND local format yield `"2023-10-04"`!!
Why? Because `1696456800000` is `2023-10-04 22:00:00 UTC`.
And in Brazil it is `2023-10-04 19:00:00 Local`.
So BOTH of them give the 4th!
There is NO WAY to get `2023-10-05` back from `1696456800000` without knowing it was Germany time (UTC+2)!
This means `DateTime` simply DOES NOT store enough information.
But wait! If the string key `"2023-10-05"` is ALREADY IN HIVE, can we just NOT recalculate it?
In `TrackedDayDataSource`, `saveTrackedDay` computes the key using `trackedDayDBO.day.toParsedDay()`.
BUT what if we DO NOT compute it, and instead `TrackedDayDBO` contains the STRING?
`TrackedDayDBO` does not contain the string key. It only has `DateTime day`.

BUT wait, table_calendar uses `DateTime.utc(y, m, d)`.
If table_calendar uses UTC, then `TrackedDayDBO.day` is `DateTime.utc(y, m, d)`.
If it's UTC, `1696464000000` is `2023-10-05 00:00:00 UTC`.
In Brazil, local format gives `2023-10-04`. BUT UTC format gives `2023-10-05`!
So if they use `DateTime.utc`, `.toUtc()` WILL FIX IT!
Let's verify if `JsonMealImporter` uses UTC or Local.
If `JsonMealImporter` uses Local, maybe we should change it to use UTC?
But wait, we can't change PAST data from `JsonMealImporter`.
Wait, in `JsonMealImporter`, `DateTime(y, m, d)` was used.

Let's read `DayBoundaryCalc._isDayLabel`.
```dart
  static bool _isDayLabel(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
```
If we run this on `TrackedDayDBO.day` in Brazil, and it was `DateTime.utc` (21:00 local), it returns FALSE.
If we run it on `DateTime.utc(y, m, d)`, `value.hour` is 0 in UTC! BUT if we load it from Hive, `value` is LOCAL!
So `value.hour` is 21! So `_isDayLabel` returns FALSE!
This means `_isDayLabel` is broken when crossing timezones!

Let's check `_isDayLabel` callers.
It's only called on `moment` inside `isMomentInLogicalDayMinutes`.
`moment` is usually `intake.dateTime`.
Wait, `IntakeDBO.dateTime` is a timestamp (e.g. 23:00). It's not a day label.
But wait, `table_calendar` produces `DateTime.utc(y, m, d)` for day labels.
And `_isDayLabel` was used for... wait!
"Some stored entries are themselves labels rather than clock readings... See [_isDayLabel] for who writes them."
Ah! "adding from the diary stamps the calendar cell itself — table_calendar hands out DateTime.utc(y, m, d)... into MealDetailBloc.addIntake as the intake's dateTime"
Wait!!! `IntakeDBO.dateTime` CAN BE A DAY LABEL!!!
If a user adds an intake from the diary, its `dateTime` is EXACTLY `DateTime.utc(y, m, d)`!
When they go to Brazil, Hive reads this `IntakeDBO.dateTime` as Local `21:00` on the 4th!
Then `_isDayLabel` returns FALSE! So it gets boundary-shifted!
And `DayBoundaryCalc` treats it as 21:00 on the 4th! So it moves to the 4th!
BUT wait! If it was a Day Label, how can we detect it if its local hour is no longer 0?
We CANNOT reliably detect it just from `.hour == 0` if it crossed timezones.
Unless we assume `IntakeDBO.dateTime` is ALWAYS a day label if it is exactly midnight in ANY UTC offset? No, that's impossible.

Wait! If we want to solve all of this:
"An entry stays on the calendar day it was logged on."
If the user logged it at 23:00 local time, they want it to stay on the 5th.
If they logged it using a Day Label, they want it to stay on the 5th.
This means we just want to format `IntakeDBO.dateTime` as the local time it WAS LOGGED IN!
But we don't have the timezone!
Wait, in PR #1224 and #1207, they say "24-hour spans vs calendar days around DST, which only cover DST".
If we look at `DayBoundaryCalc.clock = DateTime.now;`
What if the bug is not about existing DB entries moving permanently, but about HOW the app displays the calendar days?
Wait... if the app uses `day.toParsedDay()` everywhere, and `day` comes from `table_calendar` (which is `DateTime.utc`).
If `day` is `DateTime.utc(2023, 10, 5)`, `day.isUtc` is true.
What does `toParsedDay` do?
```dart
extension FormatString on DateTime {
  String toParsedDay() => DateFormat('yyyy-MM-dd').format(this);
}
```
We verified that `DateFormat('yyyy-MM-dd').format(DateTime.utc(2023, 10, 5))` returns `"2023-10-05"`.
So `table_calendar` days ALWAYS format correctly!
Wait! But what about `TrackedDayDBO.day`?
When it is loaded from Hive, it is local.
So `trackedDayDBO.day.toParsedDay()` returns `"2023-10-04"` in Brazil!
So `TrackedDayDBO` gets re-saved under the WRONG key!
This happens because `TrackedDayDBO.day` is NOT converted to UTC or used correctly.
If we change `toParsedDay` to ALWAYS use UTC?
```dart
  String toParsedDay() {
    return DateFormat('yyyy-MM-dd').format(this.isUtc ? this : this.toUtc()); // wait, no
  }
```
Wait! If `toParsedDay()` converts to UTC, what happens to REAL local times?
If a weight log was `DateTime.now()` (23:00 Brazil). Local.
`.toUtc()` makes it 02:00 next day UTC.
Format makes it the 6th! But they logged it on the 5th!
So `toParsedDay()` MUST NOT convert to UTC if it represents a local moment!

Wait, `TrackedDayDBO` is keyed by the calendar day.
Why don't we just parse the day correctly?
Is there a way we can just stringify `IntakeDBO.dateTime`? No, we don't use `toParsedDay` for IntakeDBO.
Wait, `WeightLogEntity.date` uses `toParsedDay`.
