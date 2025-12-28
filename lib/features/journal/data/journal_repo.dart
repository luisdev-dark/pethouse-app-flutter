import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';

class JournalRepository {
  JournalRepository(this._store) : _box = _store.box<JournalEntry>();

  // ignore: unused_field
  final Store _store;
  final Box<JournalEntry> _box;

  Stream<List<JournalEntry>> watchAll() {
    return _box.query().watch(triggerImmediately: true).map((query) {
      return query.find();
    });
  }
}
