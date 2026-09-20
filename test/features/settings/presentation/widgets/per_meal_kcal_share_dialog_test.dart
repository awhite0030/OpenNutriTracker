import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/per_meal_kcal_share_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';
import '../../../../helpers/test_l10n.dart';

class _FakeSettingsBloc extends Fake implements SettingsBloc {
  Map<String, int>? savedShares;

  @override
  Future<Map<String, int>> getMealKcalSharesPct() async {
    return {
      ConfigEntity.mealKeyBreakfast: 30,
      ConfigEntity.mealKeyLunch: 40,
      ConfigEntity.mealKeyDinner: 20,
      ConfigEntity.mealKeySnack: 10,
    };
  }

  @override
  Future<void> setMealKcalSharesPct(Map<String, int> pct) async {
    savedShares = pct;
  }

  @override
  void add(SettingsEvent event) {}
}

class _FakeHomeBloc extends Fake implements HomeBloc {
  @override
  void add(HomeEvent event) {}
}

class _FakeCalendarDayBloc extends Fake implements CalendarDayBloc {
  @override
  void add(CalendarDayEvent event) {}
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('typing a value applies it on submit and disables OK if not 100', (tester) async {
    final settingsBloc = _FakeSettingsBloc();
    final homeBloc = _FakeHomeBloc();
    final calendarDayBloc = _FakeCalendarDayBloc();

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PerMealKcalShareDialog(
                  settingsBloc: settingsBloc,
                  homeBloc: homeBloc,
                  calendarDayBloc: calendarDayBloc,
                ),
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final okButton = find.widgetWithText(TextButton, l10nEn.dialogOKLabel);

    // Initial values sum to 100
    expect(tester.widget<TextButton>(okButton).onPressed, isNotNull);

    // Enter value that does not sum to 100
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '50');
    // We now require submit for the state to update
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Now total is 50 + 40 + 20 + 10 = 120, which is != 100, so OK should be disabled
    expect(tester.widget<TextButton>(okButton).onPressed, isNull);

    // Entering a valid combination that sums to 100
    await tester.enterText(fields.at(1), '20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(); // 50 + 20 + 20 + 10 = 100
    expect(tester.widget<TextButton>(okButton).onPressed, isNotNull);

    await tester.tap(okButton);
    await tester.pumpAndSettle();

    expect(settingsBloc.savedShares?[ConfigEntity.mealKeyBreakfast], 50);
    expect(settingsBloc.savedShares?[ConfigEntity.mealKeyLunch], 20);
    expect(settingsBloc.savedShares?[ConfigEntity.mealKeyDinner], 20);
    expect(settingsBloc.savedShares?[ConfigEntity.mealKeySnack], 10);
  });

  testWidgets('ignores invalid typed values on submit but preserves last valid value', (tester) async {
    final settingsBloc = _FakeSettingsBloc();
    final homeBloc = _FakeHomeBloc();
    final calendarDayBloc = _FakeCalendarDayBloc();

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PerMealKcalShareDialog(
                  settingsBloc: settingsBloc,
                  homeBloc: homeBloc,
                  calendarDayBloc: calendarDayBloc,
                ),
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    // Entering a value > max allowed
    await tester.enterText(fields.first, '105');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final okButton = find.widgetWithText(TextButton, l10nEn.dialogOKLabel);
    expect(tester.widget<TextButton>(okButton).onPressed, isNotNull); // Uses previous valid value of 30

    await tester.tap(okButton);
    await tester.pumpAndSettle();

    expect(settingsBloc.savedShares?[ConfigEntity.mealKeyBreakfast], 30);
    expect(settingsBloc.savedShares?[ConfigEntity.mealKeyLunch], 40);
    expect(settingsBloc.savedShares?[ConfigEntity.mealKeyDinner], 20);
    expect(settingsBloc.savedShares?[ConfigEntity.mealKeySnack], 10);
  });
}
