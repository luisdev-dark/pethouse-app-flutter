import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/reminders/domain/reminder.dart';

class ReminderRepository {
  ReminderRepository(this._store) : _box = _store.box<Reminder>();

  // ignore: unused_field
  final Store _store;
  final Box<Reminder> _box;

  Stream<List<Reminder>> watchAll() {
    return _box.query().watch(triggerImmediately: true).map((query) {
      return query.find();
    });
  }

  int schedule(Reminder reminder) {
    return _box.put(reminder);
  }
}
