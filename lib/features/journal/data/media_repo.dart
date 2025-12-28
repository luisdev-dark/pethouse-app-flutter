import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/journal/domain/media_item.dart';

class MediaRepository {
  MediaRepository(this._store) : _box = _store.box<MediaItem>();

  // ignore: unused_field
  final Store _store;
  final Box<MediaItem> _box;

  Stream<List<MediaItem>> watchAll() {
    return _box.query().watch(triggerImmediately: true).map((query) {
      return query.find();
    });
  }

  void attachToEntry(int entryId, List<MediaItem> items) {
    for (final item in items) {
      item.entry.targetId = entryId;
      _box.put(item);
    }
  }

  void deleteForEntry(int entryId) {
    final items = _box.getAll();
    for (final item in items) {
      if (item.entry.targetId == entryId) {
        _box.remove(item.id);
      }
    }
  }
}
