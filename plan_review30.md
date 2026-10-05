Perfect!
If `_logicalDayOfTotalMinutes` returns `DateTime.utc(shifted.year, shifted.month, shifted.day)`, then `isSameLogicalDay` and `isSameLogicalDayMinutes` will just compare `dayA.year == dayB.year`, etc. and it works perfectly because they are newly created UTC DateTimes!

What about `isMomentInLogicalDayMinutes`?
```dart
  static bool isMomentInLogicalDayMinutes(
    DateTime dayLabel,
    DateTime moment,
    int? offsetTotalMinutes,
  ) {
    DateTime momentDay = _isDayLabel(moment)
        ? moment
        : logicalDayOfMinutes(moment, offsetTotalMinutes);
    // momentDay could be a fresh UTC DateTime (from logicalDayOfMinutes),
    // OR it could be `moment` directly (if it was a day label).
    // If it's `moment` directly, it might be a Local DateTime loaded from Hive!
    // So we MUST check if it's a UTC midnight and convert to UTC if necessary!
    if (momentDay.millisecondsSinceEpoch % 86400000 == 0) {
      momentDay = momentDay.toUtc();
    }

    // dayLabel might be a Local DateTime loaded from Hive, or from table_calendar.
    final dl = dayLabel.millisecondsSinceEpoch % 86400000 == 0 ? dayLabel.toUtc() : dayLabel;

    return momentDay.year == dl.year &&
        momentDay.month == dl.month &&
        momentDay.day == dl.day;
  }
```
This is robust and fixes the bug!

And in `extensions.dart`:
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

Wait, `table_calendar` produces `DateTime.utc`. What does `JsonMealImporter` do?
`JsonMealImporter` uses `DateTime(y, m, d)`. It produces LOCAL midnights.
Are LOCAL midnights affected by this?
No, their epoch is not divisible by 86400000 (except in UTC).
Wait, if a LOCAL midnight happens to be divisible by 86400000?
That only happens if the local timezone is EXACTLY UTC (e.g. GMT)!
If the local timezone is UTC, then it IS a UTC midnight! So it works perfectly!
If the local timezone is NOT UTC, it is not divisible by 86400000, so it goes to the fallback (which is identical to the old behavior).

So this is extremely safe!

Wait, is there any OTHER place we need to fix?
What about `TrackedDayDBO.day`?
If `toParsedDay()` handles UTC midnights correctly, `TrackedDayDBO.day` (which will be a UTC midnight for ALL FUTURE entries, and also for past entries logged from Diary!) will NEVER shift its Hive key!
So it will always be queried correctly!

What about `IntakeDBO.dateTime`?
If it was logged from the Diary, it's a UTC midnight.
It will be recognized by `_isDayLabel`, and `isMomentInLogicalDayMinutes` will convert it to UTC, so it will ALWAYS match the UTC `dayLabel` from `table_calendar`! So it STAYS on the calendar day it was logged on!
If it was logged from the Home Page, it's a real timestamp.
It will be subjected to `logicalDayOfMinutes`.
`logicalDayOfMinutes` will return a UTC midnight based on the LOCAL `shifted.year`/`.month`/`.day` evaluated in the CURRENT timezone.
So if they logged at 23:00 Brazil, it evaluates to 04:00 Germany. The UTC midnight will be the 6th.
Is there any way to prevent this?
No, because we don't know the original timezone.
BUT wait! The issue specifically says "A likely recipe: 1. Log food and an activity at local time UTC-3... change time zone... Open both days in the Diary."
Wait! If they log an activity, `UserActivityEntity` has `date`.
Let's see where `UserActivityEntity.date` comes from.
