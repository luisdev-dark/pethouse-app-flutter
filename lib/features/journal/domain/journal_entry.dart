import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/pets/domain/pet.dart';

@Entity()
class JournalEntry {
  @Id()
  int id = 0;

  final pet = ToOne<Pet>();

  String text;
  String? mood;

  List<String> tags;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime entryAt;

  JournalEntry({
    required this.text,
    List<String>? tags,
    this.mood,
    DateTime? createdAt,
    DateTime? entryAt,
  }) : tags = tags ?? <String>[],
       createdAt = createdAt ?? DateTime.now(),
       entryAt = entryAt ?? DateTime.now();
}
