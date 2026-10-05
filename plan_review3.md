Wait, let's trace `TrackedDayDBO.day`.
`TrackedDayDBO.day` is serialized and deserialized. When it is retrieved from `Hive`, it becomes `DateTime.fromMillisecondsSinceEpoch(epoch)`.
If we change `toParsedDay` to ALWAYS stringify the `DateTime` as a string without timezone shifts... No, `TrackedDayDBO.day` itself changes its year/month/day depending on the timezone because it was stored as epoch.
Wait! What if we change `toParsedDay`?
No, `toParsedDay` is used to build the key for `Hive` map. `Box.put(key, value)`. The key is a string.
When a user travels to Germany, the key string in Hive DOES NOT CHANGE! It was saved as `"2023-10-05"`.
But when we call `_trackedDayBox.get(day.toParsedDay())` in Germany, what is `day`?
If `day` comes from the UI (e.g. they select the 5th in the calendar), `day` is `DateTime.utc(2023, 10, 5)` (from table_calendar).
Then `day.toParsedDay()` will return `"2023-10-05"`. This matches the key perfectly!
So `TrackedDayDBO` for the 5th IS retrieved successfully in Germany!
Wait. Does table_calendar return UTC? Yes, memory says: "table_calendar hands out `DateTime.utc(y, m, d)`".

Let's verify!
If `TrackedDayDBO` for the 5th is retrieved, why does the issue say "the day total and the listed entries disagree"?
Because the entries (Intakes) are retrieved using `getAllIntakesByDate` which uses `DayBoundaryCalc.isMomentInLogicalDayMinutes`.
Let's look at `isMomentInLogicalDayMinutes`:
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
If `intake.dateTime` was recorded in Brazil at 23:00, it was 23:00 local time.
In Germany, this same absolute epoch is 04:00 local time on the 6th.
So `logicalDayOfMinutes(intake.dateTime)` returns the 6th!
So `getAllIntakesByDate(2023-10-05)` will NOT find this intake! It will find it for `2023-10-06`.
So the intake moved to the 6th!
But `TrackedDayDBO` is keyed by `"2023-10-05"` (because when they logged it in Brazil, `addDayCaloriesTracked(2023-10-05, cal)` was called).
Wait! In Brazil, `day` was `2023-10-05`. The intake was added to `TrackedDayDBO` of `2023-10-05`.
In Germany, the intake is now listed on the 6th. So the 6th has the intake in the list, but its `TrackedDayDBO` does not have those calories! And the 5th has the calories in `TrackedDayDBO`, but does not have the intake in the list!
This perfectly matches "Entries move to another day, and the day total and the listed entries disagree."

How to fix this?
We need the `IntakeDBO.dateTime` to always resolve to the original local day it was logged on, regardless of timezone changes.
But `IntakeDBO.dateTime` is stored as an epoch. It has lost its original timezone offset!
Is there any way to reconstruct the original local day?
Wait, the `TrackedDayDBO` accumulates calories.
If we want "An entry stays on the calendar day it was logged on", we need to compute its logical day in the *original timezone* it was logged in, or we need to store it differently.
But we can't change the past data easily without knowing the original timezone.
Wait! What if `IntakeDBO.dateTime` IS NOT meant to be an absolute moment?
Wait, `table_calendar` hands out UTC midnights.
But for `IntakeDBO`, `AddMealScreenArguments` sets `dateTime` to `DateTime.now()` if not provided.
If it is provided (e.g. from the diary page), it sets it to `dayLabel` (which is UTC midnight). Wait, let's check!
