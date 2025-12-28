import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/weight_record.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/shared/services/notification_service.dart';
import 'package:pethouse/shared/services/permission_service.dart';
import 'package:pethouse/shared/utils/enums.dart';

class HomeTabPage extends ConsumerWidget {
  const HomeTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsProvider);
    final selectedPetId = ref.watch(selectedPetIdProvider);
    final pets = petsAsync.asData?.value ?? <Pet>[];
    final petId = selectedPetId ?? (pets.isNotEmpty ? pets.first.id : null);

    final remindersAsync = ref.watch(remindersProvider(petId));
    final weightAsync = ref.watch(weightListProvider(petId));
    final healthAsync = ref.watch(healthSummaryProvider(petId));
    final journalAsync = petId == null
        ? const AsyncValue<List<JournalEntry>>.data(<JournalEntry>[])
        : ref.watch(journalFeedProvider(JournalFeedRequest(petId: petId)));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: petsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Text('Sin mascotas');
                }
                final currentId =
                    selectedPetId ?? (items.isNotEmpty ? items.first.id : null);
                return DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: currentId,
                    onChanged: (value) {
                      ref.read(selectedPetIdProvider.notifier).state = value;
                    },
                    items: items
                        .map(
                          (pet) => DropdownMenuItem<int>(
                            value: pet.id,
                            child: Text(pet.name),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
              loading: () => const Text('Cargando...'),
              error: (_, _) => const Text('Mascotas'),
            ),
            actions: [
              IconButton(
                onPressed: () => context.go('/reminders'),
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: 'Próximo recordatorio'),
                  const SizedBox(height: 12),
                  remindersAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const _EmptyCard(
                          title: 'Sin recordatorios',
                          subtitle: 'Configura uno nuevo para tu mascota.',
                        );
                      }
                      final next = items.first;
                      return Card(
                        child: ListTile(
                          title: Text(next.title),
                          subtitle: Text(
                            '${next.scheduledAt.day}/${next.scheduledAt.month}/${next.scheduledAt.year}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/reminders'),
                        ),
                      );
                    },
                    loading: () => const _LoadingCard(),
                    error: (_, _) => const _ErrorCard(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: weightAsync.when(
                          data: (items) {
                            final latest = items.isNotEmpty
                                ? items.first
                                : null;
                            return _MiniCard(
                              title: 'Último peso',
                              value: latest == null
                                  ? '--'
                                  : '${latest.weight.toStringAsFixed(1)} kg',
                              onTap: () => context.go('/weight/new'),
                            );
                          },
                          loading: () => const _MiniCard(
                            title: 'Último peso',
                            value: '...',
                          ),
                          error: (_, _) =>
                              const _MiniCard(title: 'Último peso', value: '!'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: healthAsync.when(
                          data: (summary) {
                            final nextVaccine =
                                summary.upcomingVaccines.isNotEmpty
                                ? summary.upcomingVaccines.first
                                : null;
                            return _MiniCard(
                              title: 'Próxima vacuna',
                              value: nextVaccine == null
                                  ? '--'
                                  : '${nextVaccine.eventAt.day}/${nextVaccine.eventAt.month}',
                              onTap: () => context.go('/health/vaccine/new'),
                            );
                          },
                          loading: () => const _MiniCard(
                            title: 'Próxima vacuna',
                            value: '...',
                          ),
                          error: (_, _) => const _MiniCard(
                            title: 'Próxima vacuna',
                            value: '!',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: journalAsync.when(
                          data: (items) {
                            final latest = items.isNotEmpty
                                ? items.first
                                : null;
                            return _MiniCard(
                              title: 'Última entrada',
                              value: latest == null ? '--' : 'Ver',
                              onTap: () {
                                if (latest != null) {
                                  context.go('/journal/${latest.id}');
                                }
                              },
                            );
                          },
                          loading: () => const _MiniCard(
                            title: 'Última entrada',
                            value: '...',
                          ),
                          error: (_, _) => const _MiniCard(
                            title: 'Última entrada',
                            value: '!',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Hoy'),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: const [
                        ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('Alimentación'),
                        ),
                        Divider(height: 0),
                        ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('Paseo'),
                        ),
                        Divider(height: 0),
                        ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('Agua fresca'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JournalTabPage extends StatelessWidget {
  const JournalTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(title: 'Diario', body: 'Entradas recientes');
  }
}

class HealthTabPage extends StatelessWidget {
  const HealthTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(title: 'Salud', body: 'Eventos de salud');
  }
}

class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(title: 'Perfil', body: 'Ajustes y cuenta');
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Bienvenido a PetHouse',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Organiza salud, diario y recordatorios de tus mascotas.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 140,
                child: PageView(
                  children: const [
                    _OnboardingCard(
                      title: 'Diario rapido',
                      body: 'Registra momentos especiales en segundos.',
                    ),
                    _OnboardingCard(
                      title: 'Vacunas al dia',
                      body: 'No pierdas ninguna fecha importante.',
                    ),
                    _OnboardingCard(
                      title: 'Alertas utiles',
                      body: 'Recordatorios para peso y medicaciones.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/pets/new'),
                  child: const Text('Crear perfil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PetSelectPage extends StatelessWidget {
  const PetSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(
      title: 'Seleccionar mascota',
      body: 'Selector de mascota',
    );
  }
}

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

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final NotificationService _notificationService = NotificationService();
  final PermissionService _permissionService = PermissionService();

  bool _notificationsEnabled = false;
  bool _photosEnabled = false;
  bool _requesting = false;

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _requesting = true;
    });
    final granted = await _permissionService.requestNotifications();
    if (granted) {
      await _notificationService.initialize();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationsEnabled = granted && value;
      _requesting = false;
    });
  }

  Future<void> _togglePhotos(bool value) async {
    setState(() {
      _requesting = true;
    });
    final granted = await _permissionService.requestPhotos();
    if (!mounted) {
      return;
    }
    setState(() {
      _photosEnabled = granted && value;
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permisos')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: _requesting ? null : _toggleNotifications,
            title: const Text('Notificaciones'),
            subtitle: const Text('Recibe recordatorios y avisos.'),
          ),
          SwitchListTile(
            value: _photosEnabled,
            onChanged: _requesting ? null : _togglePhotos,
            title: const Text('Fotos'),
            subtitle: const Text('Acceso a la galeria para fotos de mascotas.'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _requesting ? null : () => context.go('/'),
            child: const Text('Continuar'),
          ),
        ),
      ),
    );
  }
}

class JournalNewPage extends StatelessWidget {
  const JournalNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(title: 'Nuevo diario', body: 'Crear entrada');
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class JournalDetailPage extends StatelessWidget {
  const JournalDetailPage({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    return _SimpleScaffold(title: 'Entrada', body: 'Detalle: $entryId');
  }
}

class HealthVaccineNewPage extends StatelessWidget {
  const HealthVaccineNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(
      title: 'Nueva vacuna',
      body: 'Registrar vacuna',
    );
  }
}

class HealthMedicationNewPage extends StatelessWidget {
  const HealthMedicationNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(
      title: 'Nuevo medicamento',
      body: 'Registrar medicamento',
    );
  }
}

class WeightNewPage extends StatelessWidget {
  const WeightNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(title: 'Nuevo peso', body: 'Registrar peso');
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(
      title: 'Ajustes',
      body: 'Preferencias de la app',
    );
  }
}

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleScaffold(
      title: 'Recordatorios',
      body: 'Lista de recordatorios',
    );
  }
}

class _SimpleScaffold extends StatelessWidget {
  const _SimpleScaffold({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(body)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.title, required this.value, this.onTap});

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    return const _EmptyCard(
      title: 'No disponible',
      subtitle: 'Intenta nuevamente en unos segundos.',
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(title), subtitle: Text(subtitle)),
    );
  }
}
