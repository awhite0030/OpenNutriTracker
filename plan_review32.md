Wait, `day_boundary_calc_test.dart` has tests expecting `DateTime(2024, 1, 15)`.
If I changed `DayBoundaryCalc._logicalDayOfTotalMinutes` to return `DateTime.utc(...)`, then these tests are failing because `DateTime(y,m,d)` is local, and it returns UTC!
```dart
  Expected: DateTime:<2024-01-15 00:00:00.000>
    Actual: DateTime:<2024-01-15 00:00:00.000Z>
```
So I just need to update the tests in `day_boundary_calc_test.dart` to expect `DateTime.utc(y, m, d)` instead of `DateTime(y, m, d)` wherever `logicalDayOf` is checked.
