import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';
import 'package:pethouse/shared/utils/enums.dart';

@Entity()
class MediaItem {
  @Id()
  int id = 0;

  final entry = ToOne<JournalEntry>();

  int typeValue;
  String path;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  MediaItem({
    required this.typeValue,
    required this.path,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  MediaType get type => MediaType.values[typeValue];

  set type(MediaType value) => typeValue = value.index;
}
