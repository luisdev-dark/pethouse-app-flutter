import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';

class JournalRepository {
  JournalRepository(this._store) : _box = _store.box<JournalEntry>();

  // ignore: unused_field
  final Store _store;
  final Box<JournalEntry> _box;

  int createEntry(JournalEntry entry) {
    return _box.put(entry);
  }

  int saveEntry(JournalEntry entry) {
    return _box.put(entry);
  }

  void deleteEntry(int id) {
    _box.remove(id);
  }

  Stream<List<JournalEntry>> watchAll() {
    return _box.query().watch(triggerImmediately: true).map((query) {
      return query.find();
    });
  }

  Stream<JournalEntry?> watchById(int id) {
    return watchAll().map((entries) {
      for (final entry in entries) {
        if (entry.id == id) {
          return entry;
        }
      }
      return null;
    });
  }
}
