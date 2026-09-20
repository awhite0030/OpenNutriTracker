import 'package:home_widget/home_widget.dart';
import 'package:logging/logging.dart';

import '../domain/entity/intake_entity.dart';

class HomeWidgetService {
  static const String _appGroupId = 'group.com.opennutritracker';
  static const String _iosWidgetName = 'CalorieWidget';

  final Logger _logger = Logger('HomeWidgetService');

  Future<void> updateWidgetData(List<IntakeEntity> intakes, double calorieGoal) async {
    try {
      double consumedCalories = intakes.fold(0.0, (sum, item) => sum + item.totalKcal);

      await HomeWidget.setAppGroupId(_appGroupId);
      await HomeWidget.saveWidgetData<double>('consumedCalories', consumedCalories);
      await HomeWidget.saveWidgetData<double>('calorieGoal', calorieGoal);

      await HomeWidget.updateWidget(iOSName: _iosWidgetName);
      _logger.info('Successfully updated iOS widget data');
    } catch (e) {
      _logger.warning('Failed to update widget data: $e');
    }
  }
}
