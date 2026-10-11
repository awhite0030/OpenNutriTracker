import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/kcal_adjustment_dialog.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/nutrient_goals_screen.dart';
import 'package:opennutritracker/features/settings/presentation/widgets/water_goal_dialog.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';
import '../../helpers/test_l10n.dart';

class _FakeSettingsBloc extends Fake implements SettingsBloc {
  double? savedKcalAdjustment;
  int? savedWaterGoal;
  double? savedFibre;

  @override
  Future<double?> getKcalAdjustment() async => 0.0;

  @override
  Future<void> setKcalAdjustment(double adjustment) async {
    savedKcalAdjustment = adjustment;
  }

  @override
  Future<int?> getDailyWaterGoalMl() async => 2000;

  @override
  Future<void> setDailyWaterGoalMl(int goalMl) async {
    savedWaterGoal = goalMl;
  }

  @override
  Future<void> setTodayNutrientGoals(
    DateTime day, {
    double? fibreGoal,
    double? satFatGoal,
    double? sugarsGoal,
    double? sodiumGoal,
    double? calciumGoal,
    double? ironGoal,
    double? potassiumGoal,
    double? magnesiumGoal,
    double? vitaminDGoal,
    double? vitaminB12Goal,
  }) async {
    savedFibre = fibreGoal;
  }

  @override
  Future<void> updateTrackedDay(DateTime day) async {}

  @override
  void add(SettingsEvent event) {}
}

class _FakeHomeBloc extends Fake implements HomeBloc {
  @override
  void add(HomeEvent event) {}
}

class _FakeProfileBloc extends Fake implements ProfileBloc {
  @override
  void add(ProfileEvent event) {}
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => EnergyUnitProvider(usesKilojoules: false),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('KcalAdjustmentDialog saves typed values without submitting', (tester) async {
    final settingsBloc = _FakeSettingsBloc();
    final homeBloc = _FakeHomeBloc();
    final profileBloc = _FakeProfileBloc();

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => KcalAdjustmentDialog(
                  settingsBloc: settingsBloc,
                  profileBloc: profileBloc,
                  homeBloc: homeBloc,
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

    // Find text field in KcalAdjustmentDialog (identified by Semantics 'kcal-adjustment-input')
    final inputFinder = find.bySemanticsLabel(RegExp(r'kcal-adjustment-input', caseSensitive: false));
    if (inputFinder.evaluate().isEmpty) {
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, '300');
    } else {
      await tester.enterText(inputFinder.first, '300');
    }

    await tester.tap(find.text(l10nEn.dialogOKLabel));
    await tester.pumpAndSettle();

    expect(settingsBloc.savedKcalAdjustment, 300.0);
  });
}
