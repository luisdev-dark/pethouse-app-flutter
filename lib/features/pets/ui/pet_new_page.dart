import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/features/health/domain/weight_record.dart';
import 'package:pethouse/shared/utils/enums.dart';

class PetNewPage extends ConsumerStatefulWidget {
  const PetNewPage({super.key});

  @override
  ConsumerState<PetNewPage> createState() => _PetNewPageState();
}

class _PetNewPageState extends ConsumerState<PetNewPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _species;
  DateTime? _birthDate;
  PetSex? _sex;
  String? _photoPath;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
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

  Future<void> _savePet() async {
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
    );

    final petRepo = ref.read(petRepoProvider);
    final petId = petRepo.createPet(pet);

    final weightValue = double.tryParse(_weightController.text.trim());
    if (weightValue != null) {
      final record = WeightRecord(weight: weightValue);
      record.pet.targetId = petId;
      ref.read(healthRepoProvider).addWeightRecord(record);
    }

    ref.read(selectedPetIdProvider.notifier).state = petId;

    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
    });
    context.go('/permissions');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva mascota')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _savePet,
            child: Text(_saving ? 'Guardando...' : 'Guardar'),
          ),
        ),
      ),
      body: SafeArea(
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
                  initialValue: _species,
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
                    DropdownMenuItem(value: PetSex.male, child: Text('Macho')),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso inicial (opcional)',
                    suffixText: 'kg',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
