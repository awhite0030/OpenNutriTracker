Wait, what is `day` passed to `logUserActivity`?
Is it `activityEntity.date`? Yes, and `activityEntity.date` is what?
Wait! In `AddIntake`, `day` is `DateTime.utc(y, m, d)`? No, table_calendar passes `DateTime.utc(y, m, d)`.
Wait, in `AddWeightLogUsecase`:
`final today = DateTime.now().toParsedDay();`
`if (entry.date.toParsedDay() == today) { ... }`

If everything uses `.toParsedDay()`, then they compare strings formatted from LOCAL time components!
Wait! The issue:
"Probably the same family as #1224 and #1207 (24-hour spans vs calendar days around DST), which only cover DST."
What does "only cover DST" mean?
It means previously they fixed DST bugs by doing `DateTime(y, m, d+1)` instead of `.add(Duration(days:1))`.
But they forgot to handle timezone changes!
If a user goes from UTC-3 to UTC+2, it's a 5-hour shift.
A local `DateTime` representing 23:00 gets shifted by 5 hours, becoming 04:00 the next day!
So its `.year`, `.month`, `.day` change!
Wait! Memory rule says:
"In Dart, to accurately calculate the difference in calendar days between two local `DateTime` objects while avoiding errors from Daylight Saving Time (DST) transitions, convert them to UTC first: `DateTime.utc(d1.year, d1.month, d1.day).difference(DateTime.utc(d2.year, d2.month, d2.day)).inDays`."
This doesn't apply to timezone changes directly, but it shows how DST can affect duration arithmetic.

Wait! If `toParsedDay()` simply formats the local `DateTime`, how can we fix the time zone bug?
"Entries move to another day, and the day total and the listed entries disagree."
Let's see what happens if we change the timezone.
If the app stores dates using absolute epochs (via Hive's `DateTime` serializer), it will ALWAYS shift the local time when the device's timezone changes!
If we don't want the local time to shift, we should store `DateTime` in UTC!
Wait! If `IntakeDBO.dateTime` is a local wall-clock time (e.g. 23:00 Brazil), and we want it to stay 23:00 regardless of the timezone the device is currently in, we should have stored it as a UTC DateTime `DateTime.utc(2023, 10, 5, 23, ...)`!
Because Hive serializes `DateTime` as an epoch, and restores it.
Wait! If it was stored as `DateTime.utc(2023, 10, 5, 23, 0)`, Hive will serialize it as an epoch. When it reads it back, it reads it as LOCAL `DateTime.fromMillisecondsSinceEpoch(epoch)`!
But wait, no. If Hive reads it back, it is STILL the same absolute moment. So it will be 04:00 local time in Germany.
Unless Hive is configured to store something else, or we intercept the serialization.

Wait... if `TrackedDayDBO.day` is `DateTime.utc(y, m, d)`, its epoch is the absolute time of UTC midnight.
When read back by Hive in Germany, it's `DateTime.fromMillisecondsSinceEpoch(epoch)` which is local time `02:00:00` in Germany.
Wait, if it's `02:00:00` local time in Germany, `toParsedDay()` will format it as the SAME calendar day because `02:00` is on the same day as `00:00`.
But if it's read back in Brazil, it's `21:00:00` local time the day BEFORE!
So `toParsedDay()` will return the day BEFORE!
This completely explains why day totals mismatch!
Because `TrackedDayDBO.day` is `DateTime.utc(y, m, d)`. Let's verify this!
