import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/pets/domain/pet.dart';

@Entity()
class WeightRecord {
  @Id()
  int id = 0;

  final pet = ToOne<Pet>();

  double weight;

  @Property(type: PropertyType.date)
  DateTime recordedAt;

  WeightRecord({
    required this.weight,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();
}
