import 'package:objectbox/objectbox.dart';
import 'package:pethouse/shared/utils/enums.dart';

@Entity()
class Pet {
  @Id()
  int id = 0;

  String name;
  String species;
  String? breed;

  @Property(type: PropertyType.date)
  DateTime? birthDate;

  int? sexValue;
  String? photoPath;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  Pet({
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.sexValue,
    this.photoPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  PetSex? get sex =>
      sexValue == null ? null : PetSex.values[sexValue!];

  set sex(PetSex? value) => sexValue = value?.index;
}
