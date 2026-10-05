Wait, let's think about `hive` serialization for `DateTime`.
When Hive serializes a `DateTime`, does it preserve `isUtc`? No.
Actually, Hive stores `DateTime` as a 64-bit integer (`millisecondsSinceEpoch`). Wait, no!
In `hive` (or `hive_ce`), `DateTime` might be written as an integer. But wait, DOES IT PRESERVE `isUtc`?
Let's check Hive CE source for DateTime.
