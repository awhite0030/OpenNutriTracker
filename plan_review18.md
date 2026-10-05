YES! If it's a UTC midnight, its epoch modulo 86400000 is 0!
So we can detect UTC midnights perfectly regardless of the device timezone!

What about LOCAL midnights?
Are they divisible by 86400000?
No, because their epoch includes the UTC offset.
In Brazil (UTC-3), offset is -3 hours = -10800000 ms.
Modulo 86400000 is `10800000`. Not 0.
So we can't detect LOCAL midnights this way, unless we check if modulo 86400000 is a valid timezone offset?
But wait, why not just change `toParsedDay` to output the UTC string IF we know it's a UTC midnight?
If it's a UTC midnight, `this.isUtc` might be false (because of Hive), but `this.millisecondsSinceEpoch % 86400000 == 0`.
If we change `toParsedDay`:
```dart
extension FormatString on DateTime {
  String toParsedDay() {
    if (this.millisecondsSinceEpoch % 86400000 == 0) {
      return DateFormat('yyyy-MM-dd').format(this.toUtc());
    }
    return DateFormat('yyyy-MM-dd').format(this);
  }
}
```
If we do this, ANY UTC midnight loaded from Hive will CORRECTLY parse to its original UTC day!
BUT wait! What about LOCAL midnights? `JsonMealImporter` creates LOCAL midnights!
Wait, if `JsonMealImporter` creates LOCAL midnights, they are NOT divisible by 86400000.
And wait! In `DayBoundaryCalc`, `_logicalDayOfTotalMinutes` returns `DateTime(...)` which is a LOCAL midnight!
So `TrackedDayDBO.day` is created as a LOCAL midnight!
If it is a LOCAL midnight, it's NOT a UTC midnight! So it will fail the check!

So `DayBoundaryCalc` currently creates LOCAL midnights.
Why don't we change `DayBoundaryCalc` to return UTC midnights?!
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime.utc(shifted.year, shifted.month, shifted.day);
  }
```
If we change it to return UTC midnights, then ALL future day labels will be UTC midnights.
And what about past data?
Past data in Hive are LOCAL midnights.
When loaded in the SAME timezone, they format correctly (because their local hour is 0).
If the user travels, they format incorrectly.
Is there a way to fix past local midnights?
Wait! In `DayBoundaryCalc`, it says:
"A bare midnight is how this app spells "the calendar day named y-m-d" (see [isMomentInLogicalDayMinutes]). Two writers produce one, in two different spellings:"
"adding from the diary stamps the calendar cell itself — table_calendar hands out DateTime.utc(y, m, d)..."
"JsonMealImporter dates an entry DateTime(y, m, d) — local midnight..."
"Hence midnight, not the UTC flag, is the marker: keying off isUtc alone moved every date-only import back a day as soon as a boundary was configured."

Wait! If `table_calendar` produces `DateTime.utc(y, m, d)`, then `toParsedDay` WILL format it correctly IF we fix `toParsedDay` for UTC midnights!
Wait! But `DiaryBloc` creates `currentDay` via `DayBoundaryCalc.currentLogicalDayMinutes`.
And `_logicalDayOfTotalMinutes` creates `DateTime(...)`! So it produces LOCAL midnights!
Ah! If `_logicalDayOfTotalMinutes` creates LOCAL midnights, then `currentDay` is a local midnight!
Then `getTrackedDaysByRange(currentDay...)` passes local midnights!
Wait, `TrackedDayDBO.day` is assigned where?
In `AddTrackedDayUsecase.addNewTrackedDay`:
`day: day` (which comes from `currentDay` in `DiaryBloc`? No, in `LogUserActivityUsecase`, it passes `activityEntity.date`).
Wait! `activityEntity.date` is local or UTC?
Let's see. `AddIntake` uses `table_calendar` day (which is UTC).
So SOME `TrackedDayDBO.day` are UTC midnights, and SOME are Local midnights!

If we want to fix everything, we should probably standardize all day labels to UTC midnights, and for `toParsedDay()`, if we don't know the original timezone, we can't reliably fix past Local midnights.
BUT wait! We CAN fix them!
If we know a `DateTime` is a day label (it was midnight in SOME timezone), we can just say "an entry stays on the calendar day it was logged on".
Actually, wait. If an entry is a REAL timestamp (like `IntakeDBO.dateTime` 23:00 local time).
It is NOT a day label! It has hours/minutes/seconds.
How do we make it STAY on the calendar day it was logged on?
If it was logged at 23:00 Brazil (UTC-3), epoch = `1696557600000`.
In Germany (UTC+2), it is 04:00.
We want it to appear on the 5th, not the 6th!
How can we possibly know it was the 5th?
The ONLY way is to stop doing `logicalDayOfMinutes(intake.dateTime, offsetTotalMinutes)` using the device's CURRENT timezone!
BUT `logicalDayOfMinutes` uses the device's current timezone because it calls `moment.subtract()` and then `DateTime(shifted.year, ...)`.
Wait! What if we change `toParsedDay` AND `DayBoundaryCalc` to use a string-based or fixed-offset approach? We don't have the original offset.
But wait! If the user wants the entries to stay on the calendar day they were logged on...
Maybe we should just NOT convert to local time?
But Hive gives us a local DateTime that has already shifted!

Wait... "Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST."
If it's the SAME FAMILY, it means it's a bug with `DateTime` and `Duration`.
Where is `Duration` used?
In `DayBoundaryCalc`:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
Wait. If `moment` is `2023-10-05 04:00` in Germany.
`totalMinutes` is 0.
`shifted` is `2023-10-05 04:00`.
It returns `DateTime(2023, 10, 5)`. This is the 5th!
But the user logged it at 23:00 in Brazil!
So `moment` in Germany is `2023-10-06 04:00`.
It returns `DateTime(2023, 10, 6)`. So it's the 6th!
There is NO `Duration` bug here! The 23:00 timestamp genuinely BECAME 04:00 the next day!

If the bug is NOT here, where is it?
Look at `isMomentInLogicalDayMinutes`!
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
Wait, if `dayLabel` is `DateTime.utc(2023, 10, 5)` (from table_calendar).
In Brazil, `dayLabel` is `2023-10-04 21:00 Local`.
Wait! If `dayLabel` is `2023-10-04 21:00 Local`, its `.year`, `.month`, `.day` are 2023, 10, 4!
But it represents the 5th!
So `momentDay` (which might be the 5th) is compared to `dayLabel` (which is the 4th)!
So `getAllIntakesByDate(table_calendar(5th))` in Brazil will look for intakes on the 4th!
THIS IS IT!!!
If `dayLabel` is `DateTime.utc(2023, 10, 5)`, its local properties shift!
We MUST use UTC properties if it's UTC, or we must use `toParsedDay()` to compare them!
BUT `toParsedDay()` ALSO uses local properties!
So `toParsedDay()` on `DateTime.utc(2023, 10, 5)` returns `"2023-10-04"` in Brazil if it was loaded from Hive (because `isUtc` is false)!
Wait, `table_calendar` returns `DateTime.utc` with `isUtc = true`.
So `toParsedDay()` on `table_calendar(5th)` returns `"2023-10-05"` (because DateFormat on a UTC DateTime uses UTC properties!).
BUT `dayLabel.year` accesses the LOCAL properties if we are not careful?
Wait! In Dart, `.year`, `.month`, `.day` on a UTC DateTime return the UTC properties!
So `dayLabel.year` on `table_calendar(5th)` returns 2023. `.month` is 10. `.day` is 5.
BUT `TrackedDayDBO.day` loaded from Hive is LOCAL `2023-10-04 21:00`.
Its `.year` is 2023, `.month` is 10, `.day` is 4.
So `dayLabel` (5th) != `TrackedDayDBO.day` (4th)!

Wait! What if we change `toParsedDay` to convert EVERYTHING to a fixed format, but how?
We can't, because we don't know the timezone.
BUT wait! We CAN change how we store and compare day labels!
If we change ALL day labels to be formatted strictly in UTC?
