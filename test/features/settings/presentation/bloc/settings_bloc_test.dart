import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_tracked_day_usecase.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';

import 'settings_bloc_test.mocks.dart';

@GenerateMocks([
  GetConfigUsecase,
  AddConfigUsecase,
  AddTrackedDayUsecase,
  GetKcalGoalUsecase,
  GetMacroGoalUsecase,
  RemoteSearchCacheDataSource,
  GetTrackedDayUsecase,
])
void main() {
  late MockGetConfigUsecase mockGetConfigUsecase;
  late MockAddConfigUsecase mockAddConfigUsecase;
  late MockAddTrackedDayUsecase mockAddTrackedDayUsecase;
  late MockGetKcalGoalUsecase mockGetKcalGoalUsecase;
  late MockGetMacroGoalUsecase mockGetMacroGoalUsecase;
  late MockRemoteSearchCacheDataSource mockRemoteSearchCacheDataSource;
  late MockGetTrackedDayUsecase mockGetTrackedDayUsecase;
  late SettingsBloc settingsBloc;

  setUp(() {
    mockGetConfigUsecase = MockGetConfigUsecase();
    mockAddConfigUsecase = MockAddConfigUsecase();
    mockAddTrackedDayUsecase = MockAddTrackedDayUsecase();
    mockGetKcalGoalUsecase = MockGetKcalGoalUsecase();
    mockGetMacroGoalUsecase = MockGetMacroGoalUsecase();
    mockRemoteSearchCacheDataSource = MockRemoteSearchCacheDataSource();
    mockGetTrackedDayUsecase = MockGetTrackedDayUsecase();

    settingsBloc = SettingsBloc(
      mockGetConfigUsecase,
      mockAddConfigUsecase,
      mockAddTrackedDayUsecase,
      mockGetKcalGoalUsecase,
      mockGetMacroGoalUsecase,
      mockRemoteSearchCacheDataSource,
      mockGetTrackedDayUsecase,
    );
  });

  group('updateTrackedDay', () {
    test('updates day calorie and macro goals if tracked day exists', () async {
      final day = DateTime(2023, 1, 1);
      const totalKcalGoal = 2000.0;
      const totalCarbsGoal = 250.0;
      const totalFatGoal = 60.0;
      const totalProteinGoal = 100.0;

      when(mockGetKcalGoalUsecase.getKcalGoal()).thenAnswer((_) async => totalKcalGoal);
      when(mockGetMacroGoalUsecase.getCarbsGoal(totalKcalGoal)).thenAnswer((_) async => totalCarbsGoal);
      when(mockGetMacroGoalUsecase.getFatsGoal(totalKcalGoal)).thenAnswer((_) async => totalFatGoal);
      when(mockGetMacroGoalUsecase.getProteinsGoal(totalKcalGoal)).thenAnswer((_) async => totalProteinGoal);
      when(mockAddTrackedDayUsecase.hasTrackedDay(day)).thenAnswer((_) async => true);

      await settingsBloc.updateTrackedDay(day);

      verify(mockAddTrackedDayUsecase.updateDayCalorieGoal(day, totalKcalGoal)).called(1);
      verify(mockAddTrackedDayUsecase.updateDayMacroGoals(
        day,
        carbsGoal: totalCarbsGoal,
        fatGoal: totalFatGoal,
        proteinGoal: totalProteinGoal,
      )).called(1);
      verifyNever(mockAddTrackedDayUsecase.addNewTrackedDay(any, any, any, any, any));
    });

    test('adds new tracked day if tracked day does not exist', () async {
      final day = DateTime(2023, 1, 1);
      const totalKcalGoal = 2000.0;
      const totalCarbsGoal = 250.0;
      const totalFatGoal = 60.0;
      const totalProteinGoal = 100.0;

      when(mockGetKcalGoalUsecase.getKcalGoal()).thenAnswer((_) async => totalKcalGoal);
      when(mockGetMacroGoalUsecase.getCarbsGoal(totalKcalGoal)).thenAnswer((_) async => totalCarbsGoal);
      when(mockGetMacroGoalUsecase.getFatsGoal(totalKcalGoal)).thenAnswer((_) async => totalFatGoal);
      when(mockGetMacroGoalUsecase.getProteinsGoal(totalKcalGoal)).thenAnswer((_) async => totalProteinGoal);
      when(mockAddTrackedDayUsecase.hasTrackedDay(day)).thenAnswer((_) async => false);

      await settingsBloc.updateTrackedDay(day);

      verify(mockAddTrackedDayUsecase.addNewTrackedDay(
        day,
        totalKcalGoal,
        totalCarbsGoal,
        totalFatGoal,
        totalProteinGoal,
      )).called(1);
    });
  });
}
