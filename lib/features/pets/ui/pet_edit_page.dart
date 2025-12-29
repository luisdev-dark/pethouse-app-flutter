import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/shared/utils/enums.dart';

class PetEditPage extends ConsumerStatefulWidget {
  const PetEditPage({super.key});

  @override
  ConsumerState<PetEditPage> createState() => _PetEditPageState();
}

class _PetEditPageState extends ConsumerState<PetEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _vetNameController;
  late TextEditingController _vetPhoneController;
  late TextEditingController _vetAddressController;

  // Note: Weight is managed in Health tab, so we don't edit it here to avoid conflicts.

  final _imagePicker = ImagePicker();

  String? _species;
  DateTime? _birthDate;
  PetSex? _sex;
  String? _photoPath;
  bool _saving = false;
  bool _initialized = false;
  int? _petId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _breedController = TextEditingController();
    _vetNameController = TextEditingController();
    _vetPhoneController = TextEditingController();
    _vetAddressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _vetNameController.dispose();
    _vetPhoneController.dispose();
    _vetAddressController.dispose();
    super.dispose();
  }

  void _initData(Pet pet) {
    if (_initialized) return;
    _petId = pet.id;
    _nameController.text = pet.name;
    _breedController.text = pet.breed ?? '';
    _vetNameController.text = pet.vetName ?? '';
    _vetPhoneController.text = pet.vetPhone ?? '';
    _vetAddressController.text = pet.vetAddress ?? '';
    _species = pet.species;
    _birthDate = pet.birthDate;
    _sex = pet.sex;
    _photoPath = pet.photoPath;
    _initialized = true;
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final separator = Platform.pathSeparator;
    final extension = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${directory.path}${separator}pet_$timestamp.$extension';
    final savedFile = await File(file.path).copy(targetPath);

    if (!mounted) {
      return;
    }
    setState(() {
      _photoPath = savedFile.path;
    });
  }

  Future<void> _updatePet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_species == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una especie.')));
      return;
    }

    setState(() {
      _saving = true;
    });

    final pet = Pet(
      name: _nameController.text.trim(),
      species: _species!,
      breed: _breedController.text.trim().isEmpty
          ? null
          : _breedController.text.trim(),
      birthDate: _birthDate,
      sexValue: _sex?.index,
      photoPath: _photoPath,
      vetName: _vetNameController.text.trim().isEmpty
          ? null
          : _vetNameController.text.trim(),
      vetPhone: _vetPhoneController.text.trim().isEmpty
          ? null
          : _vetPhoneController.text.trim(),
      vetAddress: _vetAddressController.text.trim().isEmpty
          ? null
          : _vetAddressController.text.trim(),
    );
    // Assign ID to update existing record
    if (_petId != null) {
      pet.id = _petId!;
    }

    final petRepo = ref.read(petRepoProvider);
    // Reuse createPet which is effectively a put/save
    petRepo.createPet(pet);

    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
    });
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(selectedPetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar mascota')),
      body: petAsync.when(
        data: (pet) {
          if (pet == null) {
            return const Center(
              child: Text('Error: No se encontró la mascota.'),
            );
          }
          _initData(pet);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundImage: _photoPath == null
                                ? null
                                : FileImage(File(_photoPath!)),
                            child: _photoPath == null
                                ? const Icon(Icons.pets, size: 32)
                                : null,
                          ),
                          IconButton(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un nombre.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _species, // Might need check if value exists in items
                      decoration: const InputDecoration(labelText: 'Especie'),
                      items: const [
                        DropdownMenuItem(value: 'Perro', child: Text('Perro')),
                        DropdownMenuItem(value: 'Gato', child: Text('Gato')),
                        DropdownMenuItem(value: 'Ave', child: Text('Ave')),
                        DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _species = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: 'Raza (opcional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha de nacimiento'),
                      subtitle: Text(
                        _birthDate == null
                            ? 'Opcional'
                            : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(now.year - 25),
                            lastDate: now,
                            initialDate: _birthDate ?? now,
                          );
                          if (!mounted || picked == null) {
                            return;
                          }
                          setState(() {
                            _birthDate = picked;
                          });
                        },
                        icon: const Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<PetSex>(
                      initialValue: _sex,
                      decoration: const InputDecoration(
                        labelText: 'Sexo (opcional)',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: PetSex.male,
                          child: Text('Macho'),
                        ),
                        DropdownMenuItem(
                          value: PetSex.female,
                          child: Text('Hembra'),
                        ),
                        DropdownMenuItem(
                          value: PetSex.unknown,
                          child: Text('No definido'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sex = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Datos Veterinarios',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vetNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Veterinaria/Doctor',
                        prefixIcon: Icon(Icons.local_hospital),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vetPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vetAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _updatePet,
                        child: Text(_saving ? 'Guardando...' : 'Actualizar'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, trace) =>
            const Center(child: Text('Error al cargar la mascota')),
      ),
    );
  }
}
