import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/features/health/domain/weight_record.dart';

class HealthRepository {
  HealthRepository(this._store)
    : _eventBox = _store.box<HealthEvent>(),
      _weightBox = _store.box<WeightRecord>();

  // ignore: unused_field
  final Store _store;
  final Box<HealthEvent> _eventBox;
  final Box<WeightRecord> _weightBox;

  Stream<List<HealthEvent>> watchEvents() {
    return _eventBox.query().watch(triggerImmediately: true).map((query) {
      return query.find();
    });
  }

  Stream<List<WeightRecord>> watchWeights() {
    return _weightBox.query().watch(triggerImmediately: true).map((query) {
      return query.find();
    });
  }

  int addWeightRecord(WeightRecord record) {
    return _weightBox.put(record);
  }

  int addVaccine(HealthEvent event) {
    return _eventBox.put(event);
  }
}
