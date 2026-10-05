Wait, `dateTime: day`!
And `day` is passed into `addIntake`:
`DateTime? day`
If `day` is null, it defaults to `DateTime.now()`!
Let's check where `addIntake` is called.
