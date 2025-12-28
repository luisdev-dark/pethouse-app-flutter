import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/shared/utils/enums.dart';

@Entity()
class Reminder {
  @Id()
  int id = 0;

  final pet = ToOne<Pet>();

  int typeValue;
  String title;

  @Property(type: PropertyType.date)
  DateTime scheduledAt;

  String? repeatRule;
  bool isEnabled;
  int? relatedEventId;

  Reminder({
    required this.typeValue,
    required this.title,
    DateTime? scheduledAt,
    this.repeatRule,
    this.isEnabled = true,
    this.relatedEventId,
  }) : scheduledAt = scheduledAt ?? DateTime.now();

  HealthEventType get type => HealthEventType.values[typeValue];

  set type(HealthEventType value) => typeValue = value.index;
}
