Yes! `DayBoundaryCalc` literally says:
"table_calendar hands out `DateTime.utc(y, m, d)`, which DayInfoWidget passes through AddMealScreenArguments into MealDetailBloc.addIntake as the intake's `dateTime`"
And `JsonMealImporter` dates an entry `DateTime(y, m, d)` (local midnight).

So wait, `table_calendar` produces `DateTime.utc(2023, 10, 5)`.
Then `TrackedDayDBO.day` receives this UTC DateTime.
Hive stores its epoch.
When retrieved, Hive creates a LOCAL DateTime from that epoch!
Since `DateTime.utc(2023, 10, 5)` is UTC midnight, its epoch represents midnight in UTC.
In Brazil (UTC-3), that epoch represents `2023-10-04 21:00:00 Local`.
When `toParsedDay()` is called on this restored DateTime, it returns `"2023-10-04"`!
This means the `TrackedDayDBO` created on the 5th will be mapped to `"2023-10-04"` when the app starts in Brazil!
But the user created it in Germany (UTC+2) where it mapped to `"2023-10-05"`.
This causes the database to mismatch, shift days, etc.

But what if the user logs a LOCAL `DateTime.now()`?
It stores the absolute epoch. In Brazil it was 23:00.
When they travel to Germany (UTC+2), that epoch becomes 04:00 local time the next day.
When `getAllIntakesByDate` is called with `2023-10-05` (a UTC midnight from table_calendar, or local midnight), `isMomentInLogicalDayMinutes` compares the shifted `momentDay`.
Wait! `_isDayLabel` has this check:
```dart
  static bool _isDayLabel(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
```
If a UTC midnight (`DateTime.utc(y, m, d)`) is loaded from Hive in Brazil, it's `21:00 Local`.
Its `hour` is `21`. So `_isDayLabel` returns `FALSE`!
This means `DayBoundaryCalc` will apply the boundary shift to it!

The core problem is that Hive's `DateTime` serialization does NOT preserve `isUtc`.
Wait! If we can't change Hive's serialization format, what CAN we do?
We can change `toParsedDay`? No, because `IntakeDBO.dateTime` is a timestamp, and we want to preserve its original calendar day! But it lost its original timezone.
Wait, if it's a "day label" (it was exactly midnight UTC OR exactly midnight local when stored), can we detect it?
If it was midnight local, its hour was 0. When they travel, its hour changes. We can't detect it easily without assuming that anything close to midnight is a day label.
Wait! What if we just fix `isMomentInLogicalDayMinutes`? No, because `IntakeDBO.dateTime` (a real timestamp) also shifts.
"Entries move to another day" means real timestamps shift across calendar days.
How can we stop real timestamps from shifting?
If an intake was logged at 23:00 Brazil, its absolute epoch is 02:00 UTC next day.
If the app wants it to STAY on the 5th, then the app must NOT format it based on the CURRENT device timezone!
But since `DateTime` doesn't store the original timezone, the app has NO WAY to know it was originally on the 5th!
UNLESS... the app shouldn't be using absolute epochs for timestamps?
But `IntakeDBO` uses `DateTime` which is serialized as absolute epoch by Hive.
Is there ANY way to know the original calendar day?
Wait... what if Hive's `DateTime` serializer just serializes it as a string?
If it serialized it as a string, it would be `2023-10-05T23:00:00.000`. And when read back, it would be exactly that.
But Hive is an external library. Does OpenNutriTracker have a custom TypeAdapter for DateTime?
