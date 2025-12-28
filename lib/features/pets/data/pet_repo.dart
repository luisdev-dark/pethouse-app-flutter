import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/pets/domain/pet.dart';

class PetRepository {
  PetRepository(this._store) : _box = _store.box<Pet>();

  // ignore: unused_field
  final Store _store;
  final Box<Pet> _box;

  int createPet(Pet pet) {
    return _box.put(pet);
  }

  Stream<List<Pet>> watchAll() {
    return _box.query().watch(triggerImmediately: true).map((query) {
      return query.find();
    });
  }

  Stream<Pet?> watchById(int id) {
    return watchAll().map((pets) {
      for (final pet in pets) {
        if (pet.id == id) {
          return pet;
        }
      }
      return null;
    });
  }
}
