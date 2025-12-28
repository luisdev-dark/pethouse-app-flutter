import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/shared/utils/enums.dart';

@Entity()
class HealthEvent {
  @Id()
  int id = 0;

  final pet = ToOne<Pet>();

  int typeValue;
  String title;
  String? notes;

  @Property(type: PropertyType.date)
  DateTime eventAt;

  @Property(type: PropertyType.date)
  DateTime? nextAt;

  HealthEvent({
    required this.typeValue,
    required this.title,
    this.notes,
    DateTime? eventAt,
    this.nextAt,
  }) : eventAt = eventAt ?? DateTime.now();

  HealthEventType get type => HealthEventType.values[typeValue];

  set type(HealthEventType value) => typeValue = value.index;
}
