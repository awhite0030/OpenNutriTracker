The issue describes bugs related to entries moving to another calendar day when traveling across time zones.
The `toParsedDay` extension function format `DateTime` into `yyyy-MM-dd` format string. It's used everywhere to store `TrackedDayDBO` or `WeightLogDBO` entries using a date string as key.

Let's look at `toParsedDay` definition in `lib/core/utils/extensions.dart`:
```dart
extension FormatString on DateTime {
  String toParsedDay() => DateFormat('yyyy-MM-dd').format(this);
}
```

As tested, `DateFormat` formats the components of the DateTime as they are, without modifying them. So it depends on how the DateTime components `year`, `month`, `day` are affected by the time zone.

Wait, if we use local time (which varies by time zone):
When the user stores `DateTime(2023, 10, 5, 0)` in Brazil (UTC-3), it corresponds to epoch 1696474800000.
When the user goes to Germany (UTC+2) and the database loads the same epoch (1696474800000) as local time, it is constructed in Dart as `DateTime.fromMillisecondsSinceEpoch(1696474800000)`, which has local time `2023-10-05 05:00`. `toParsedDay` still outputs `2023-10-05`. This looks correct... Wait.

What if the user records the entry at `23:00` in Brazil?
`DateTime(2023, 10, 5, 23)` has epoch 1696557600000.
In Germany, this epoch evaluates to local time `2023-10-06 04:00`.
Then `toParsedDay()` will return `2023-10-06`!
And since it uses `toParsedDay()` to group tracked day objects by day, this tracked day object is now associated with the 6th of October instead of the 5th.
Wait, `TrackedDayDBO.day` is always midnight (a day label), not 23:00. The code stores a day label in TrackedDayDBO.day: `DateTime(2023, 10, 5, 0)` in Brazil, which gets deserialized as `2023-10-05 05:00` in Germany.
Wait, if it's `2023-10-05 05:00`, `toParsedDay` returns `2023-10-05`. So it doesn't move.

Wait, what if they stored it in Germany at `02:00` local time?
`DateTime(2023, 10, 5, 2)` (epoch 1696464000000 in Germany).
In Brazil, this epoch is `2023-10-04 21:00`.
`toParsedDay()` will return `2023-10-04`. So it moved a day backward!

Ah! Wait! Hive serializes DateTime fields. TrackedDayDBO.day is a Hive field. Hive does not use `toParsedDay()` to serialize it, it just serializes it as an epoch. When it retrieves it, it reconstructs it as local `DateTime` with the epoch. And its local string formatting using `toParsedDay` produces different results.

Wait, `IntakeDBO.dateTime` is the wall-clock time the user logged the activity.
For example, if they logged food at `23:00` in Brazil. The intake is stored with that wall-clock time epoch.
Then, `getAllIntakesByDate` checks `DayBoundaryCalc.isMomentInLogicalDayMinutes(dayLabel, intake.dateTime, totalMinutes)`.
`dayLabel` comes from the UI (the calendar day).
`intake.dateTime` is the stored local time. Wait, if the stored `intake.dateTime` epoch gets loaded in Germany, it shifts its `local` time.

Let's test this carefully. How can we fix this?
If we want a calendar day string regardless of timezone shifts, we shouldn't just rely on `DateFormat('yyyy-MM-dd').format(this)`. Wait, no, the calendar day *should* be independent of when we format it, but `this` is a local DateTime based on epoch, so its `.year`, `.month`, `.day` change when timezone changes.
No, actually, the problem is that we are storing "Day Labels" as `local` DateTime in Hive!
When a day label (which is exactly `yyyy-MM-dd 00:00:00.000 Local`) is serialized as an epoch, it represents a specific absolute moment. In a different timezone, that absolute moment has a different local time, and therefore might have a different date!
For example, midnight in Germany is 19:00 the previous day in Brazil!
So if they create a day label `2023-10-05 00:00:00` in Germany and travel to Brazil, when they load the app, it's `2023-10-04 19:00:00`. So it becomes a day label for October 4th!
This breaks `toParsedDay()` and also breaks `TrackedDayDBO.day`.

The fix: we should ALWAYS handle day labels as `UTC` when serializing and formatting? Or at least, if `toParsedDay` just wants the original year/month/day, what can it do? `DateTime` doesn't remember its original timezone.
Wait. The issue says: "A likely recipe: 1. Log food and an activity at local time UTC-3 on two consecutive days. 2. Change the device time zone to UTC+2. 3. Open both days in the Diary."

Let's see #1224 and #1207.
If we change `DayBoundaryCalc._logicalDayOfTotalMinutes`:
```dart
  static DateTime _logicalDayOfTotalMinutes(DateTime moment, int totalMinutes) {
    final shifted = moment.subtract(Duration(minutes: totalMinutes));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }
```
Wait, Memory says: "In Dart, to accurately calculate the difference in calendar days between two local `DateTime` objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
Also Memory says: "In Dart, use calendar-day arithmetic via `DateTime` constructors (e.g., `DateTime(date.year, date.month, date.day - 1)`) instead of `Duration` subtraction (`date.subtract(Duration(days: 1))`) for manipulating full calendar days, as `Duration` uses wall-clock hours and may fail across DST boundaries."

Wait, how are `toParsedDay` and other Date handling methods written?
```dart
extension FormatString on DateTime {
  String toParsedDay() => DateFormat('yyyy-MM-dd').format(this);
}
```

Wait, `TrackedDayDBO.day` (the day label) is used to compute `toParsedDay()`.
If `day` was `2023-10-05 00:00:00` in Germany.
In Brazil it's `2023-10-04 19:00:00`. `toParsedDay()` will return `2023-10-04`.
This means the `TrackedDayDBO` saved in Germany will be placed under the key `2023-10-04` when updated in Brazil!
But the user expects it to stay on `2023-10-05`!
Wait, but if `day` is `2023-10-04 19:00:00`, it's not a day label anymore according to `DayBoundaryCalc._isDayLabel` because its hour is 19, not 0!

Wait, `IntakeDBO.dateTime` is a timestamp. If they log it at 23:00 in Brazil, the time is 23:00 local, and the day label is Brazil's today (e.g. 5th). In Germany, the time becomes 04:00 the next day (6th). Its local day label will be the 6th. So it moves to the 6th in Germany.
Is this expected? "An entry stays on the calendar day it was logged on."
Ah! The actual behavior: "Entries move to another day, and the day total and the listed entries disagree."
So the user expects: if they logged it on the 5th (in Brazil), it stays on the 5th (even in Germany).
But `DateTime.now()` is recorded as the absolute moment (UTC timestamp), and when loaded in Germany, its local day is the 6th, so it appears on the 6th!
BUT wait, how is `intake.dateTime` stored? It's a `DateTime` (epoch).
If we want entries to stick to the calendar day they were logged on, we shouldn't use absolute timestamps to determine their calendar day!
Wait, wait. OpenNutriTracker uses absolute timestamps (`DateTime.now()`) for intakes.
If you travel, the local time of that absolute timestamp changes, and so its local calendar day changes.
BUT the `TrackedDayDBO` was accumulated based on the calendar day it was *logged*. So `TrackedDayDBO` recorded the calories on the 5th.
Now, the intake shows up on the 6th, but `TrackedDayDBO` (the day total) for the 5th still has the calories (wait, unless the TrackedDayDBO label also shifted).
If `TrackedDayDBO.day` was a midnight local DateTime, it shifted from 5th to 4th (or 6th).
This explains why "the day total and the listed entries disagree". The `TrackedDayDBO` shifted by one timezone difference (midnight shifted), but `IntakeDBO` shifted by the same timezone difference, but from a different hour (23:00 shifted to 04:00 next day). They don't shift across midnight at the same time!

If the requirement is "An entry stays on the calendar day it was logged on", then we shouldn't rely on the device's current timezone to format historical `DateTime` objects, or we should use UTC for storing calendar days?
Wait! In `DayBoundaryCalc`, they just added `DayBoundaryCalc.isMomentInLogicalDayMinutes(dayLabel, moment, offset)`.
Wait, how does `_isDayLabel` identify a day label?
```dart
  static bool _isDayLabel(DateTime value) =>
      value.hour == 0 &&
      value.minute == 0 &&
      value.second == 0 &&
      value.millisecond == 0 &&
      value.microsecond == 0;
```
If a user created a day label `2023-10-05 00:00:00` in Germany and travels to Brazil, it becomes `2023-10-04 19:00:00`.
Then `_isDayLabel` will return FALSE! It will treat it as a clock reading!

How can we fix all this?
If we look at `test_tz` above, we noticed that `DateTime` does not store the original timezone.
If we want an entry to stay on the calendar day it was logged on, we have a few options, but we cannot change the database schema arbitrarily because of backward compatibility.
Wait, `DateTime` objects in Dart *do not* store timezone.
When Hive serializes `DateTime`, it stores the `millisecondsSinceEpoch`.
Wait! Is it possible to store `IntakeDBO.dateTime` as UTC? No, they already store it as local (which means it's an absolute epoch, just printed in local timezone). Wait! If it's stored as an absolute epoch, traveling changes its local date.
If we want the calendar day to be fixed, shouldn't `IntakeDBO` store the calendar day explicitly? But it only has `DateTime dateTime`.
How can we make "An entry stays on the calendar day it was logged on" true without schema changes?
Look at `day.toParsedDay()`: what if we just format it based on the original offset? But we don't have the original offset.
Wait! What if they stored `intake.dateTime` NOT as an absolute epoch, but by some other means?
No, we must work with existing `DateTime` stored in Hive.
Wait, if they created a `DateTime` using `DateTime(2023, 10, 5, 23)`, it's a local `DateTime`. Its epoch is `UTC - offset`.
If we change how `DayBoundaryCalc` computes things? No, `IntakeDBO` has `DateTime dateTime`.

Wait, let's read the issue carefully: "Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST."
In #1224 and #1207, the fix was to avoid using `Duration(days: 1)` or `Duration(hours: 24)` and instead use `DateTime(y, m, d + 1)`.
Wait! Is it possible that the issue is NOT about `IntakeDBO.dateTime` shifting its local hour?
Wait, if an entry "stays on the calendar day it was logged on", how does the app know which calendar day it was logged on?
If the app uses `DateTime.now()` (wall clock), and saves it as epoch. When traveling, it's the SAME absolute moment. A moment that was 23:00 in Brazil is 04:00 in Germany. It naturally falls on the next day.
Wait, if it was logged as 23:00 in Brazil, and we look at it in Germany, does the user want it to say 23:00 (Brazil time) and be on the 5th? OR do they want it to say 04:00 and be on the 6th?
The issue says: "Expected behaviour: An entry stays on the calendar day it was logged on."
This implies the app *should* format dates using their ORIGINAL local time, or at least treat them as having a fixed calendar day.
But Dart's `DateTime` does not store the original timezone!
So if they only have the epoch, how can they know it was logged on the 5th?
Wait! Does Hive serialize `DateTime` as epoch?
Let's check `hive` serialization for `DateTime`.
