import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/widgets/day_info_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:mockito/mockito.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:provider/provider.dart';

class _FakeDiaryBloc extends Fake implements DiaryBloc {
  @override
  DateTime currentDay = DateTime(2026, 1, 20); // 20th is the logical current day
}

Widget _wrapWithMaterial(Widget child) {
  return ChangeNotifierProvider<EnergyUnitProvider>(
    create: (_) => EnergyUnitProvider(),
    child: MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUpAll(() {
    final locator = GetIt.instance;
    locator.registerFactory<DiaryBloc>(_FakeDiaryBloc.new);
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  testWidgets(
    'DayInfoWidget uses DiaryBloc.currentDay to determine if copy is allowed',
    (WidgetTester tester) async {
      final selectedDayPast = DateTime(2026, 1, 19); // 19th is past

      await tester.pumpWidget(_wrapWithMaterial(DayInfoWidget(
        trackedDayEntity: null,
        selectedDay: selectedDayPast,
        userActivities: const [],
        breakfastIntake: const [],
        lunchIntake: const [],
        dinnerIntake: const [],
        snackIntake: const [],
        onDeleteIntake: (_, __) {},
        onDeleteActivity: (_, __) {},
        onCopyIntake: (_, __, ___) {},
        onCopyActivity: (_, __) {},
        onEditIntake: (_, __, ___) {},
        onEditActivity: (_, __) {},
        usesImperialUnits: false,
        showMealMacros: false,
        showActivityTracking: false,
        breakfastKcalTarget: 0,
        lunchKcalTarget: 0,
        dinnerKcalTarget: 0,
        snackKcalTarget: 0,
        breakfastSharePct: 0,
        lunchSharePct: 0,
        dinnerSharePct: 0,
        snackSharePct: 0,
        diarySortPreferences: const {},
      )));

      await tester.pumpAndSettle();

      expect(find.text('Nothing added'), findsOneWidget);
    },
  );
}
