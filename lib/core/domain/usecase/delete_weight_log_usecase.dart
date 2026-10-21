import 'package:opennutritracker/core/data/repository/weight_log_repository.dart';
import 'package:opennutritracker/core/domain/entity/weight_log_entity.dart';

class DeleteWeightLogUsecase {
  final WeightLogRepository _weightLogRepository;

  DeleteWeightLogUsecase(this._weightLogRepository);

  Future<void> deleteEntry(WeightLogEntity entry) async {
    await _weightLogRepository.deleteEntryByKey(entry.storageKey, entry.date);
  }
}
