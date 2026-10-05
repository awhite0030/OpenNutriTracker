Wait, let's look at `TrackedDayDBO.day`.
`TrackedDayDBO` has `DateTime day;`.
If the user logged in Brazil, `day` was `DateTime.utc(y, m, d)`. (Because table_calendar provides it).
Wait! Does `table_calendar` provide it as UTC?
Memory: "table_calendar hands out DateTime.utc(y, m, d)".
If `TrackedDayDBO` uses this `DateTime.utc(y, m, d)`. It is stored as an epoch.
When retrieved from Hive, it becomes a LOCAL DateTime.
In Brazil, `DateTime.utc(2023, 10, 5)` was epoch `1696464000000`.
If retrieved in Brazil, it's `2023-10-04 21:00`.
Wait, if they logged in Brazil, and they are still in Brazil, when they open the app, it's `2023-10-04 21:00`!!
Then `toParsedDay()` will return `"2023-10-04"`!
Then why doesn't it break IMMEDIATELY without traveling?!
Let's test this!
