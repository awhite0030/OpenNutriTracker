So, here is the plan to fix UTC midnights (which represent Day Labels from `table_calendar`) so they NEVER shift when moving across timezones:

1. Update `DayBoundaryCalc._isDayLabel` to identify UTC midnights regardless of local timezone.
   ```dart
   static bool _isDayLabel(DateTime value) {
     return (value.hour == 0 && value.minute == 0 && value.second == 0 && value.millisecond == 0 && value.microsecond == 0) ||
            (value.millisecondsSinceEpoch % 86400000 == 0);
   }
   ```
2. Update `DayBoundaryCalc.isMomentInLogicalDayMinutes` to compare UTC properties if the arguments are UTC midnights.
   ```dart
   static bool isMomentInLogicalDayMinutes(
     DateTime dayLabel,
     DateTime moment,
     int? offsetTotalMinutes,
   ) {
     DateTime momentDay = _isDayLabel(moment)
         ? moment
         : logicalDayOfMinutes(moment, offsetTotalMinutes);

     if (momentDay.millisecondsSinceEpoch % 86400000 == 0) {
       momentDay = momentDay.toUtc();
     }
     final dl = dayLabel.millisecondsSinceEpoch % 86400000 == 0 ? dayLabel.toUtc() : dayLabel;

     return momentDay.year == dl.year &&
         momentDay.month == dl.month &&
         momentDay.day == dl.day;
   }
   ```
3. Update `extensions.dart` `toParsedDay` to output the UTC string if it's a UTC midnight. This ensures `TrackedDayDBO.day` (which is often a UTC midnight) keeps the same Hive key in every timezone!
   ```dart
   extension FormatString on DateTime {
     String toParsedDay() {
       if (millisecondsSinceEpoch % 86400000 == 0) {
         return DateFormat('yyyy-MM-dd').format(toUtc());
       }
       return DateFormat('yyyy-MM-dd').format(this);
     }
   }
   ```
4. Update `DayBoundaryCalc._logicalDayOfTotalMinutes` to return UTC midnights instead of Local midnights, so that all future Day Labels are reliably UTC midnights!
   ```dart
   static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
     final shifted = moment.subtract(Duration(minutes: totalMinutes));
     return DateTime.utc(shifted.year, shifted.month, shifted.day);
   }
   ```

Wait! Is there any other place where `_isDayLabel` or UTC midnights are handled?
Wait! If `_logicalDayOfTotalMinutes` returns `DateTime.utc(shifted.year, ...)`, then `isSameLogicalDayMinutes` will compare UTC midnights.
```dart
  static bool isSameLogicalDayMinutes(
    DateTime a,
    DateTime b,
    int? offsetTotalMinutes,
  ) {
    final dayA = logicalDayOfMinutes(a, offsetTotalMinutes);
    final dayB = logicalDayOfMinutes(b, offsetTotalMinutes);
    // Since dayA and dayB are now UTC midnights, their local .year/.month/.day might be shifted in some timezones!
    // We MUST compare their UTC properties!
    return dayA.toUtc().year == dayB.toUtc().year &&
        dayA.toUtc().month == dayB.toUtc().month &&
        dayA.toUtc().day == dayB.toUtc().day;
  }
```
Wait, if they are `DateTime.utc(...)`, their `isUtc` is true.
If `isUtc` is true, `dayA.year` returns the UTC year! So `dayA.year == dayB.year` is ALREADY correct!
BUT if they were loaded from Hive (e.g. they are passed into `isSameLogicalDayMinutes`), they might be Local DateTimes with `isUtc = false`.
So we should just do `.toUtc()` to be safe, because they are UTC midnights (modulo 86400000).

Let's refine `DayBoundaryCalc`:

```dart
  static bool isSameLogicalDayMinutes(
    DateTime a,
    DateTime b,
    int? offsetTotalMinutes,
  ) {
    DateTime dayA = logicalDayOfMinutes(a, offsetTotalMinutes);
    DateTime dayB = logicalDayOfMinutes(b, offsetTotalMinutes);

    if (dayA.millisecondsSinceEpoch % 86400000 == 0) dayA = dayA.toUtc();
    if (dayB.millisecondsSinceEpoch % 86400000 == 0) dayB = dayB.toUtc();

    return dayA.year == dayB.year &&
        dayA.month == dayB.month &&
        dayA.day == dayB.day;
  }
```

Wait, `isSameLogicalDay` (the old one) delegates to `logicalDayOf`.
So it's covered.

Let's verify `toParsedDay`:
If `TrackedDayDBO.day` was created as UTC midnight in Germany, its epoch is `1696464000000`.
In Brazil, it loads as `2023-10-04 21:00:00 Local`.
`toParsedDay()` checks `1696464000000 % 86400000 == 0` (True).
Returns `DateFormat('yyyy-MM-dd').format(toUtc())`.
`.toUtc()` makes it `2023-10-05 00:00:00 UTC`.
Format returns `"2023-10-05"`.
This is exactly the original key! It works perfectly!

What if it was a LOCAL midnight created by `JsonMealImporter`?
In Brazil, `2023-10-05 00:00:00 Local`. Epoch is `1696474800000`.
Modulo 86400000 is NOT 0.
So it formats using Local DateFormat. Returns `"2023-10-05"`. Works perfectly in Brazil.
In Germany, it's `2023-10-05 05:00:00 Local`.
Modulo 86400000 is NOT 0.
Formats using Local DateFormat. Returns `"2023-10-05"`. Works perfectly in Germany!
Wait! Local midnights ALSO work perfectly because their timezone shift (e.g. +5 hours) does NOT push them across midnight!
BUT if they went from Germany to Brazil (-5 hours), `2023-10-05 00:00:00 Local Germany` becomes `2023-10-04 19:00:00 Local Brazil`.
Then it formats as `"2023-10-04"`.
So it shifts. BUT we cannot prevent Local midnights from shifting because we can't reliably detect them.
However, `TrackedDayDBO` is NOT created by `JsonMealImporter`. It is created by `addNewTrackedDay`.
`addNewTrackedDay` uses `currentDay` from `DiaryBloc`, which uses `DayBoundaryCalc.currentLogicalDayMinutes`.
So if we change `_logicalDayOfTotalMinutes` to return UTC midnights, ALL new `TrackedDayDBO` will be UTC midnights!
And for old ones that were Local midnights, they will shift, but we can't help it.
Wait! What if they were ALREADY created as Local midnights?
Is there a way to fix past Local midnights?
If we know it's a day label because it's EXACTLY midnight in the CURRENT timezone, `toParsedDay` already formats it correctly!
If it shifted (e.g. 19:00), we don't know if it was a Local midnight.
So this is the BEST POSSIBLE FIX without data migration.
