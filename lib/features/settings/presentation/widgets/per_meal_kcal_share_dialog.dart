import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/meal_pattern_entity.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// #150: Split the daily kcal goal across breakfast / lunch / dinner /
/// snack. Preset chips (#150 follow-up) drop in pre-authored splits for IF /
/// OMAD / five-small-meals routines without making the user dial them in.
class PerMealKcalShareDialog extends StatefulWidget {
  final SettingsBloc settingsBloc;
  final HomeBloc homeBloc;
  final CalendarDayBloc calendarDayBloc;

  const PerMealKcalShareDialog({
    super.key,
    required this.settingsBloc,
    required this.homeBloc,
    required this.calendarDayBloc,
  });

  @override
  State<PerMealKcalShareDialog> createState() => _PerMealKcalShareDialogState();
}

class _PerMealKcalShareDialogState extends State<PerMealKcalShareDialog> {
  double _breakfastPct = 30;
  double _lunchPct = 40;
  double _dinnerPct = 20;
  double _snackPct = 10;
  bool _loaded = false;
  bool _syncingControllers = false;
  _MealField? _lastEditedMeal;

  late final TextEditingController _breakfastController;
  late final TextEditingController _lunchController;
  late final TextEditingController _dinnerController;
  late final TextEditingController _snackController;

  @override
  void initState() {
    super.initState();
    _breakfastController = TextEditingController();
    _lunchController = TextEditingController();
    _dinnerController = TextEditingController();
    _snackController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _snackController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final shares = await widget.settingsBloc.getMealKcalSharesPct();
    if (!mounted) return;
    setState(() {
      _breakfastPct = (shares[ConfigEntity.mealKeyBreakfast] ?? 30).toDouble();
      _lunchPct = (shares[ConfigEntity.mealKeyLunch] ?? 40).toDouble();
      _dinnerPct = (shares[ConfigEntity.mealKeyDinner] ?? 20).toDouble();
      _snackPct = (shares[ConfigEntity.mealKeySnack] ?? 10).toDouble();
      _loaded = true;
    });
    _syncControllers();
  }

  void _syncControllers() {
    _syncingControllers = true;
    try {
      _breakfastController.text = _breakfastPct.round().toString();
      _lunchController.text = _lunchPct.round().toString();
      _dinnerController.text = _dinnerPct.round().toString();
      _snackController.text = _snackPct.round().toString();
    } finally {
      _syncingControllers = false;
    }
  }

  void _markLastEdited(_MealField field) {
    if (_syncingControllers) return;
    _lastEditedMeal = field;
  }

  /// Presets are authored to sum to 100 already.
  void _applyPreset(MealPatternEntity pattern) {
    setState(() {
      _breakfastPct = pattern.breakfastPct.toDouble();
      _lunchPct = pattern.lunchPct.toDouble();
      _dinnerPct = pattern.dinnerPct.toDouble();
      _snackPct = pattern.snackPct.toDouble();
    });
    _syncControllers();
  }

  String _presetLabel(BuildContext context, MealPatternEntity pattern) {
    final s = S.of(context);
    switch (pattern) {
      case MealPatternEntity.standard:
        return s.mealPatternStandard;
      case MealPatternEntity.mediterranean:
        return s.mealPatternMediterranean;
      case MealPatternEntity.twoMeal:
        return s.mealPatternTwoMeal;
      case MealPatternEntity.omad:
        return s.mealPatternOmad;
      case MealPatternEntity.fiveSmall:
        return s.mealPatternFiveSmall;
    }
  }

  bool _isValidPercentage(int? value) => value != null && value >= 0 && value <= 100;

  int? _parsePercentage(TextEditingController controller) {
    final parsed = int.tryParse(controller.text);
    return _isValidPercentage(parsed) ? parsed : null;
  }

  void _applyBreakfastInput() {
    final parsed = _parsePercentage(_breakfastController);
    if (parsed == null) {
      _syncControllers();
      return;
    }
    setState(() {
      _breakfastPct = parsed.toDouble();
    });
    _syncControllers();
  }

  void _applyLunchInput() {
    final parsed = _parsePercentage(_lunchController);
    if (parsed == null) {
      _syncControllers();
      return;
    }
    setState(() {
      _lunchPct = parsed.toDouble();
    });
    _syncControllers();
  }

  void _applyDinnerInput() {
    final parsed = _parsePercentage(_dinnerController);
    if (parsed == null) {
      _syncControllers();
      return;
    }
    setState(() {
      _dinnerPct = parsed.toDouble();
    });
    _syncControllers();
  }

  void _applySnackInput() {
    final parsed = _parsePercentage(_snackController);
    if (parsed == null) {
      _syncControllers();
      return;
    }
    setState(() {
      _snackPct = parsed.toDouble();
    });
    _syncControllers();
  }

  void _applyPendingTextInputs() {
    switch (_lastEditedMeal) {
      case _MealField.breakfast:
        _applyBreakfastInput();
        break;
      case _MealField.lunch:
        _applyLunchInput();
        break;
      case _MealField.dinner:
        _applyDinnerInput();
        break;
      case _MealField.snack:
        _applySnackInput();
        break;
      case null:
        break;
    }
  }

  Future<void> _save() async {
    _applyPendingTextInputs();

    // Re-validate total in case pending text makes it invalid
    final totalPct = _breakfastPct.round() + _lunchPct.round() + _dinnerPct.round() + _snackPct.round();

    if (totalPct != 100) return;

    await widget.settingsBloc.setMealKcalSharesPct({
      ConfigEntity.mealKeyBreakfast: _breakfastPct.round(),
      ConfigEntity.mealKeyLunch: _lunchPct.round(),
      ConfigEntity.mealKeyDinner: _dinnerPct.round(),
      ConfigEntity.mealKeySnack: _snackPct.round(),
    });
    widget.settingsBloc.add(LoadSettingsEvent());
    widget.homeBloc.add(const LoadItemsEvent());
    widget.calendarDayBloc.add(RefreshCalendarDayEvent());
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _breakfastPct = (ConfigEntity.defaultMealKcalSharesPct[ConfigEntity.mealKeyBreakfast]!).toDouble();
      _lunchPct = (ConfigEntity.defaultMealKcalSharesPct[ConfigEntity.mealKeyLunch]!).toDouble();
      _dinnerPct = (ConfigEntity.defaultMealKcalSharesPct[ConfigEntity.mealKeyDinner]!).toDouble();
      _snackPct = (ConfigEntity.defaultMealKcalSharesPct[ConfigEntity.mealKeySnack]!).toDouble();
    });
    _syncControllers();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final totalPct = _breakfastPct.round() + _lunchPct.round() + _dinnerPct.round() + _snackPct.round();
    final isValidTotal = totalPct == 100;
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(s.settingsPerMealKcalShareLabel, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          TextButton(onPressed: _loaded ? _reset : null, child: Text(s.buttonResetLabel)),
        ],
      ),
      content: !_loaded
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.settingsPerMealKcalShareDescription, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Text(s.mealPatternPresetsLabel, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final pattern in MealPatternEntity.values)
                        Semantics(
                          identifier: 'meal-share-preset-${pattern.id}',
                          child: OutlinedButton(
                            onPressed: () => _applyPreset(pattern),
                            child: Text(_presetLabel(context, pattern)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$totalPct% total',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: isValidTotal ? null : Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  _MealShareRow(
                    label: s.settingsPerMealKcalShareBreakfast,
                    value: _breakfastPct,
                    identifier: 'meal-share-breakfast',
                    controller: _breakfastController,
                    onSliderChanged: (v) {
                      setState(() {
                        _breakfastPct = v;
                      });
                    },
                    onSliderEnd: _syncControllers,
                    onTextChanged: (_) => _markLastEdited(_MealField.breakfast),
                    onTextSubmitted: _applyBreakfastInput,
                  ),
                  _MealShareRow(
                    label: s.settingsPerMealKcalShareLunch,
                    value: _lunchPct,
                    identifier: 'meal-share-lunch',
                    controller: _lunchController,
                    onSliderChanged: (v) {
                      setState(() {
                        _lunchPct = v;
                      });
                    },
                    onSliderEnd: _syncControllers,
                    onTextChanged: (_) => _markLastEdited(_MealField.lunch),
                    onTextSubmitted: _applyLunchInput,
                  ),
                  _MealShareRow(
                    label: s.settingsPerMealKcalShareDinner,
                    value: _dinnerPct,
                    identifier: 'meal-share-dinner',
                    controller: _dinnerController,
                    onSliderChanged: (v) {
                      setState(() {
                        _dinnerPct = v;
                      });
                    },
                    onSliderEnd: _syncControllers,
                    onTextChanged: (_) => _markLastEdited(_MealField.dinner),
                    onTextSubmitted: _applyDinnerInput,
                  ),
                  _MealShareRow(
                    label: s.settingsPerMealKcalShareSnack,
                    value: _snackPct,
                    identifier: 'meal-share-snack',
                    controller: _snackController,
                    onSliderChanged: (v) {
                      setState(() {
                        _snackPct = v;
                      });
                    },
                    onSliderEnd: _syncControllers,
                    onTextChanged: (_) => _markLastEdited(_MealField.snack),
                    onTextSubmitted: _applySnackInput,
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.dialogCancelLabel)),
        Semantics(
          identifier: 'meal-share-save',
          child: TextButton(onPressed: (_loaded && isValidTotal) ? _save : null, child: Text(s.dialogOKLabel)),
        ),
      ],
    );
  }
}

class _MealShareRow extends StatelessWidget {
  final String label;
  final double value;
  final String identifier;
  final TextEditingController controller;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onSliderEnd;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onTextSubmitted;

  const _MealShareRow({
    required this.label,
    required this.value,
    required this.identifier,
    required this.controller,
    required this.onSliderChanged,
    required this.onSliderEnd,
    required this.onTextChanged,
    required this.onTextSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(96),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  suffixText: '%',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                onChanged: onTextChanged,
                onSubmitted: (_) => onTextSubmitted(),
                onEditingComplete: onTextSubmitted,
              ),
            ),
          ],
        ),
        Semantics(
          identifier: identifier,
          child: Slider(
            min: 0,
            max: 100,
            value: value.clamp(0, 100),
            divisions: 100,
            onChanged: onSliderChanged,
            onChangeEnd: (_) => onSliderEnd(),
          ),
        ),
      ],
    );
  }
}

enum _MealField { breakfast, lunch, dinner, snack }
