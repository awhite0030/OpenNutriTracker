Wait, `IntakeDBO.dateTime` is the timestamp.
Memory rule says:
"In Dart, to accurately calculate the difference in calendar days between two local `DateTime` objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
Wait, "Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST."
Ah! Is the issue caused by `toParsedDay` returning the local time string, and Hive storing the epoch?
Let's look at `toParsedDay`:
```dart
extension FormatString on DateTime {
  String toParsedDay() => DateFormat('yyyy-MM-dd').format(this);
}
```
If we use `DateTime.utc(2023, 10, 5)` to store a day, it is stored as an epoch corresponding to `2023-10-05 00:00:00 UTC`.
If we format it using `toParsedDay`, DateFormat looks at its local components.
Wait! We proved that `DateTime.utc(2023, 10, 5).toLocal()` produces different dates.
Wait! Does `DateFormat('yyyy-MM-dd').format(dtUtc)` use the UTC components or the local components?
We tested `test_tz22.dart` earlier:
```dart
  final dtUtc = DateTime.utc(dtLocal.year, dtLocal.month, dtLocal.day);
  print('toParsedDay (UTC): ${DateFormat('yyyy-MM-dd').format(dtUtc)}');
```
And it printed `2023-10-05`.
Wait! DateFormat in Dart does NOT convert to local time before formatting! It uses the components as they are (`dt.year`, `dt.month`, `dt.day`).
So if we pass `DateTime.utc(2023, 10, 5)`, it formats as `2023-10-05` in EVERY timezone.
BUT, when Hive serializes a `DateTime`, does it serialize `isUtc`?
We tested `test_hive_dt.dart` earlier. No, Hive does NOT serialize `isUtc`!
When Hive reads the epoch `1696464000000` (which is `2023-10-05 00:00:00 UTC`), it creates a `DateTime.fromMillisecondsSinceEpoch(1696464000000)`, which is a LOCAL `DateTime` by default!
Since it's a LOCAL `DateTime`, its `.year`, `.month`, `.day` will be evaluated in the device's local timezone.
In Germany (UTC+2), `1696464000000` represents `2023-10-05 02:00:00`. So DateFormat prints `2023-10-05`.
In Brazil (UTC-3), `1696464000000` represents `2023-10-04 21:00:00`. So DateFormat prints `2023-10-04`!
AHA!!!

This means if a `TrackedDayDBO.day` was created using `DateTime.utc(2023, 10, 5)` and saved to Hive, it's stored as `1696464000000`.
When the user goes to Brazil, Hive reads `1696464000000` as a local DateTime: `2023-10-04 21:00:00`.
Then we call `trackedDay.day.toParsedDay()`. It returns `"2023-10-04"`.
But the key in the Hive map is STILL `"2023-10-05"` (because the string key doesn't change)!
Wait, if `TrackedDayDBO.day.toParsedDay()` returns `"2023-10-04"`, when we update the day in Brazil, `saveTrackedDay` will do:
`await _trackedDayBox.put(trackedDayDBO.day.toParsedDay(), trackedDayDBO);`
This will save it under the key `"2023-10-04"`!
This effectively duplicates or moves the `TrackedDayDBO` to a new day!

What about `WeightLogEntity`?
It has `DateTime date`. It is also saved using `date.toParsedDay()`.

What about `IntakeDBO.dateTime`?
`IntakeDBO.dateTime` is recorded using `DateTime.now()` (e.g. 23:00 Brazil = 02:00 UTC next day).
When traveling to Germany, Hive reads the epoch and parses it as local time in Germany.
So 23:00 Brazil -> 04:00 Germany. So it moves from the 5th to the 6th.

So the root cause is that `DateTime` objects stored in Hive are deserialized as LOCAL time, and the app relies on their `.year`, `.month`, `.day` (via `toParsedDay()` or `DayBoundaryCalc`) which shift with the local timezone.

If we want to fix this, how do we make calendar days independent of time zones?
We want `"2023-10-05"` to always be `"2023-10-05"`.
But we can't change how Hive deserializes `DateTime`.
Wait! For `IntakeDBO.dateTime`, we CANNOT just ignore the timezone, because it represents an absolute moment. But wait! The issue says:
"Entries move to another day... An entry stays on the calendar day it was logged on."
If a user logs an entry at 23:00 on the 5th in Brazil, they want it to appear on the 5th everywhere in the world!
This means `IntakeDBO.dateTime` SHOULD NOT BE TREATED AS AN ABSOLUTE MOMENT for the purpose of calendar assignment.
Instead, it should be treated as "wall-clock time" (i.e. if it says 23:00, it's 23:00 regardless of where you are now).
But if it's stored as an absolute epoch, we lose the original wall-clock time!
Wait... Is there a way to store dates as strings instead? Yes, but that requires a migration.
Is there an easier way?
