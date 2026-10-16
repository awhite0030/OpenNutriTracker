import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_gender_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_pal_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/nutrient_goals_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

import 'nutrient_goals_screen_test.mocks.dart';

@GenerateMocks([SettingsBloc, ProfileBloc, DiaryBloc, CalendarDayBloc, HomeBloc])
void main() {
  late MockSettingsBloc mockSettingsBloc;
  late MockProfileBloc mockProfileBloc;
  late MockDiaryBloc mockDiaryBloc;
  late MockCalendarDayBloc mockCalendarDayBloc;
  late MockHomeBloc mockHomeBloc;

  setUp(() {
    mockSettingsBloc = MockSettingsBloc();
    mockProfileBloc = MockProfileBloc();
    mockDiaryBloc = MockDiaryBloc();
    mockCalendarDayBloc = MockCalendarDayBloc();
    mockHomeBloc = MockHomeBloc();
  });

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      home: NutrientGoalsScreen(
        settingsBloc: mockSettingsBloc,
        profileBloc: mockProfileBloc,
        diaryBloc: mockDiaryBloc,
        calendarDayBloc: mockCalendarDayBloc,
        homeBloc: mockHomeBloc,
      ),
    );
  }

  testWidgets('NutrientGoalsScreen defaults to gender-specific DRIs when unconfigured', (tester) async {
    // 30-year-old female
    final user = UserEntity(
      birthday: DateTime.now().subtract(const Duration(days: 30 * 365)),
      heightCM: 165,
      weightKG: 65,
      gender: UserGenderEntity.female,
      goal: UserWeightGoalEntity.maintainWeight,
      pal: UserPALEntity.lowActive,
    );

    when(mockProfileBloc.getUser()).thenAnswer((_) async => user);
    when(mockSettingsBloc.getTodayTrackedDay(any)).thenAnswer((_) async => null);

    // Provide a large enough viewport to ensure the slider is painted without scrolling
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    Finder finderBySemantics(String id) {
      return find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.identifier == id);
    }

    final fibreSemantics = finderBySemantics('nutrient-fibre-slider');
    await tester.dragUntilVisible(fibreSemantics, find.byType(ListView).first, const Offset(0, -500));
    final fibreSlider = tester.widget<Slider>(find.descendant(of: fibreSemantics, matching: find.byType(Slider)));
    expect(fibreSlider.value, 25.0);

    final ironSemantics = finderBySemantics('nutrient-iron-slider');
    await tester.dragUntilVisible(ironSemantics, find.byType(ListView).first, const Offset(0, -500));
    final ironSlider = tester.widget<Slider>(find.descendant(of: ironSemantics, matching: find.byType(Slider)));
    expect(ironSlider.value, 18.0);

    // Reset window size
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
