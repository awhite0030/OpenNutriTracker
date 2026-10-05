So DateTime uses the default Hive TypeAdapter.
Wait, if the user complains that "Entries move to another day, and the day total and the listed entries disagree", AND "An entry stays on the calendar day it was logged on" is the EXPECTED behavior.
This exactly means that the user expects `DateTime` in this app to behave as a WALL-CLOCK time with no timezone conversion.
For example, if I log at 23:00, it should be 23:00 everywhere.
But Dart's `DateTime` and Hive's epoch serialization inherently convert things.
Wait... what if `IntakeDBO.dateTime` was logged as Local.
If we want to fix this WITHOUT migrating the DB, how do we do it?
We can't... because if it's stored as epoch, we have no idea what the original timezone was. So we can't reconstruct the original local time.
Wait, if we CAN'T reconstruct the original local time, how can we make it "stay on the calendar day it was logged on"?
Look at the issue description:
"A likely recipe: 1. Log food and an activity at local time UTC-3 on two consecutive days. 2. Change the device time zone to UTC+2. 3. Open both days in the Diary."
If we look at `DayBoundaryCalc._isDayLabel(DateTime value)`
Wait, could it be that the only problem is that `toParsedDay()` converts UTC to Local?
No, `toParsedDay()` just formats the `DateTime`.
If `TrackedDayDBO.day` is `DateTime.utc(y, m, d)`.
When Hive deserializes it, it deserializes it as a local `DateTime.fromMillisecondsSinceEpoch(epoch)`.
If we change `toParsedDay` to:
```dart
extension FormatString on DateTime {
  String toParsedDay() {
    // If it is a UTC timestamp, DateFormat formats it as UTC.
    // BUT Hive deserializes it as LOCAL. So this is a local DateTime.
    // Can we determine if it was originally a UTC midnight?
    // Not easily if it shifted by an arbitrary timezone offset.
  }
}
```
Wait! Is it possible to use `DateTime.utc` instead of `DateTime.now().toParsedDay()`?
Wait, if we change `toParsedDay()`? No, it's used for keys! If we change how keys are computed from existing `DateTime`, we might break existing keys? No, keys are strings. `TrackedDayDBO` is queried from Hive via `_trackedDayBox.get(day.toParsedDay())`. `day` here is a `DateTime` (a local one? or UTC? from table_calendar it's UTC).
So `day.toParsedDay()` for `DateTime.utc(2023, 10, 5)` returns `"2023-10-05"`. This works perfectly and queries the right key.

So the ONLY problem is:
1. `TrackedDayDBO` itself has a `.day` field. When updated, `saveTrackedDay` uses `trackedDayDBO.day.toParsedDay()`.
Because `trackedDayDBO.day` was loaded from Hive, it's a LOCAL DateTime representing the original UTC midnight epoch.
In Brazil (UTC-3), it's `2023-10-04 21:00`. So `toParsedDay()` returns `"2023-10-04"`!
Then `saveTrackedDay` saves it under `"2023-10-04"` instead of `"2023-10-05"`.
This causes the `TrackedDayDBO` to MOVE to the previous day!
AND `IntakeDBO.dateTime` also has problems?
"Entries move to another day, and the day total and the listed entries disagree."
If `TrackedDayDBO` moved to the previous day, its totals are now on the previous day.
And `IntakeDBO.dateTime` (a local epoch) might also shift to the previous day (or next day) depending on the time it was logged and the timezone change.
But wait! What if we just fix `TrackedDayDBO.day` and `WeightLogDBO.date` and `UserActivityDBO.date` to be UTC before calling `toParsedDay()`?
If `trackedDayDBO.day` is `2023-10-04 21:00 Local` (because it was originally UTC midnight `1696464000000`), we can convert it to UTC!
`trackedDayDBO.day.toUtc()` -> `2023-10-05 00:00 UTC`!
Then if we format THAT, we get `"2023-10-05"`!
Wait! Is it true that `TrackedDayDBO.day.toUtc()` will always be exactly midnight?
Let's check!
If it was originally created as `DateTime.utc(2023, 10, 5)`. Its epoch is `1696464000000`.
When loaded in Brazil, it's `2023-10-04 21:00 Local`.
If we call `.toUtc()` on it, it becomes `2023-10-05 00:00 UTC`.
Then `toParsedDay()` on the UTC object will return `"2023-10-05"`.
Wait! Does `toParsedDay()` format the UTC object as `"2023-10-05"`?
Yes! DateFormat formats the `.year`, `.month`, `.day` of the DateTime object, regardless of whether it's UTC or Local.
So if we call `.toUtc()` on a DateTime, its `.year`, `.month`, `.day` are its UTC components!
So `DateFormat('yyyy-MM-dd').format(dt.toUtc())` will ALWAYS return `"2023-10-05"` for this epoch!

Wait... did they originally create `TrackedDayDBO.day` as UTC midnight?
Let's check `DayBoundaryCalc._isDayLabel` again.
"table_calendar hands out `DateTime.utc(y, m, d)` ... JsonMealImporter dates an entry `DateTime(y, m, d)` — *local* midnight"
Uh oh! `JsonMealImporter` uses LOCAL midnight!
If it used LOCAL midnight in Germany, its epoch is `2023-10-05 00:00 Local` (UTC-2 = `2023-10-04 22:00 UTC`).
If we call `.toUtc()` on that, it becomes `2023-10-04 22:00 UTC`.
Then `toParsedDay()` on that UTC object will return `"2023-10-04"`! Which is wrong!

This means we CANNOT just use `.toUtc()`!
Wait, but if `JsonMealImporter` uses LOCAL midnight, its `.hour` was 0.
But after moving to Brazil, it's `2023-10-04 19:00 Local`.
Its UTC is `2023-10-04 22:00 UTC`.
Both Local and UTC are `2023-10-04`. So it moved to the 4th permanently!
Is this what they meant by "Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST)"?
No, the issue is EXACTLY about `toParsedDay()` changing.

Let's read the codebase again.
In PR #1309 (wait, this IS issue #1309).
How do we make `TrackedDayDBO.day` and `WeightLogDBO.date` independent of timezones?
If `toParsedDay()` is the only thing defining the calendar day, why is it implemented as:
```dart
extension FormatString on DateTime {
  String toParsedDay() => DateFormat('yyyy-MM-dd').format(this);
}
```
If we change it to:
```dart
  String toParsedDay() {
    // ???
  }
```
There's no way to reliably know what it was originally.
Unless... wait. What if we just stop using `.toParsedDay()` on the stored `day` field, and instead use it strictly on the `DateTime` passed from the UI?
Wait, if `TrackedDayDBO` is stored, its key is `"2023-10-05"`.
Why does `saveTrackedDay` use `trackedDayDBO.day.toParsedDay()` instead of the original key?
```dart
  Future<void> saveTrackedDay(TrackedDayDBO trackedDayDBO) async {
    log.fine('Updating tracked day in db');
    await _trackedDayBox.put(trackedDayDBO.day.toParsedDay(), trackedDayDBO);
  }
```
If `trackedDayDBO.day.toParsedDay()` evaluates to `"2023-10-04"` in Brazil, it writes it to the WRONG key!
What if `TrackedDayDBO` didn't use `day.toParsedDay()` but we just used the string key everywhere?
But wait, `TrackedDayDBO` has `day`. If we display `day` in the UI, it will show the 4th instead of the 5th!
Does the UI display `TrackedDayDBO.day`?
