import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import '../helpers/hive_test_setup.dart';
import '../helpers/fake_hive_db_provider.dart';

void main() {
  group('TrackedDayRepository', () {
    late Box<TrackedDayDBO> box;
    late TrackedDayDataSource dataSource;
    late TrackedDayRepository repository;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerHiveAdaptersOnce();
    });

    setUp(() async {
      Hive.init('.');
      box = await Hive.openBox<TrackedDayDBO>('tracked_day_repo_test');
      dataSource = TrackedDayDataSource(FakeHiveDBProvider(trackedDayBox: box));
      repository = TrackedDayRepository(dataSource);
    });

    tearDown(() async {
      await box.clear();
      await Hive.close();
      await Hive.deleteFromDisk();
    });

    test('addNewTrackedDay copies nutrient goals from previous day', () async {
      final day1 = DateTime.utc(2024, 1, 15);
      final day2 = DateTime.utc(2024, 1, 16);

      await dataSource.saveTrackedDay(
        TrackedDayDBO(day: day1, calorieGoal: 2000, caloriesTracked: 1500, fibreGoal: 30, ironGoal: 20),
      );

      await repository.addNewTrackedDay(day2, 2000, 250, 65, 150);

      final result = await dataSource.getTrackedDay(day2);
      expect(result!.fibreGoal, equals(30));
      expect(result.ironGoal, equals(20));
      expect(result.calciumGoal, isNull);
    });
  });
}
