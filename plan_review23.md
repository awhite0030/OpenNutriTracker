Wait, `addIntake` takes `DateTime day`.
If they open the Diary, `day` is `table_calendar`'s UTC midnight!
And it gets assigned to `intakeEntity.dateTime: day`!
Wait! So `IntakeDBO.dateTime` IS EXACTLY a Day Label from the diary!
If `IntakeDBO.dateTime` is `DateTime.utc(2023, 10, 5)`.
When saved to Hive, it's `1696464000000`.
When retrieved in Brazil, it's `2023-10-04 21:00:00`.
Its `hour` is 21!
So `_isDayLabel(intake.dateTime)` returns FALSE!
Then `logicalDayOfMinutes(intake.dateTime)` evaluates its logical day.
Since it is 21:00 on the 4th, its logical day is the 4th (or 5th depending on offset)!
Wait, if it evaluates to the 4th, it DOES NOT match `dayLabel` (which is the 5th)!
So it MOVES to the 4th!
BUT wait! The issue says they "log food and an activity at local time UTC-3... then change to UTC+2".
If they log food and an activity in UTC-3, and its `hour` is 0 (because they used the Diary page which passes UTC midnight? Wait, does the Diary page pass UTC midnight or local time?).
Wait! "table_calendar hands out `DateTime.utc(y, m, d)` which DayInfoWidget passes... into MealDetailBloc.addIntake as the intake's `dateTime`"
This EXACTLY explains it!
`IntakeDBO.dateTime` IS a Day Label!
But `_isDayLabel` fails to identify it as a Day Label when the timezone changes, because `isUtc` is lost and `hour` is no longer 0!

If `_isDayLabel` fails, then `DayBoundaryCalc` subjects it to boundary subtraction!
And it moves to another day!
If we FIX `_isDayLabel` to correctly identify Day Labels, it will stop shifting!
Wait! How can we identify a Day Label if it lost its timezone?
If it was UTC midnight, its epoch is exactly divisible by `86400000` (1000 * 60 * 60 * 24).
If it was LOCAL midnight (like `JsonMealImporter`), its epoch is NOT divisible by `86400000`. But wait, does it matter if we can't identify past Local midnights?
Wait, if it was a Local midnight, its local hour WAS 0. When they travel, its local hour is NO LONGER 0. So it fails `_isDayLabel`.
But if we modify `_isDayLabel` to check for UTC midnight:
```dart
  static bool _isDayLabel(DateTime value) =>
      (value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0) || (value.millisecondsSinceEpoch % 86400000 == 0);
```
If we do this, ANY entry that was a UTC midnight will ALWAYS be recognized as a Day Label, regardless of the current device timezone!
And since `table_calendar` produces UTC midnights, ALL entries logged from the Diary are UTC midnights!
Wait, what if they were logged from the Home page?
Home page logs use `DateTime.now()`? Let's check `HomeBloc`.
