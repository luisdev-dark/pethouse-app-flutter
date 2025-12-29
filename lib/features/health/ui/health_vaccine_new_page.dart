import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/features/reminders/domain/reminder.dart';
import 'package:pethouse/shared/services/notification_service.dart';
import 'package:pethouse/shared/utils/enums.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class HealthVaccineNewPage extends ConsumerStatefulWidget {
  const HealthVaccineNewPage({super.key});

  @override
  ConsumerState<HealthVaccineNewPage> createState() =>
      _HealthVaccineNewPageState();
}

class _HealthVaccineNewPageState extends ConsumerState<HealthVaccineNewPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _appliedAt = DateTime.now();
  DateTime? _nextAt;
  bool _createReminder = true;
  String? _selectedVaccineName;
  String? _attachmentPath;
  bool _saving = false;

  static const List<String> _vaccineOptions = <String>[
    'Rabia',
    'Moquillo',
    'Parvovirus',
    'Combinada',
    'Personalizada',
  ];

  @override
  void dispose() {
    _customNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPetId = ref.watch(selectedPetIdProvider);
    if (selectedPetId == null) {
      return const SimpleScaffold(
        title: 'Nueva vacuna',
        body: 'Selecciona una mascota en Inicio antes de registrar una vacuna.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar vacuna')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _save(selectedPetId),
            child: Text(_saving ? 'Guardando...' : 'Guardar'),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedVaccineName,
                decoration: const InputDecoration(labelText: 'Vacuna'),
                items: _vaccineOptions
                    .map(
                      (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVaccineName = value;
                  });
                },
                validator: (value) {
                  if (value == null && _customNameController.text.isEmpty) {
                    return 'Selecciona una vacuna o escribe un nombre.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre personalizado (opcional)',
                  hintText: 'Ej. Refuerzo anual',
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha aplicada'),
                subtitle: Text(
                  '${_appliedAt.day.toString().padLeft(2, '0')}/${_appliedAt.month.toString().padLeft(2, '0')}/${_appliedAt.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickAppliedDate(context),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Próxima fecha (opcional)'),
                subtitle: Text(
                  _nextAt == null
                      ? 'Sin próxima fecha'
                      : '${_nextAt!.day.toString().padLeft(2, '0')}/${_nextAt!.month.toString().padLeft(2, '0')}/${_nextAt!.year}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_nextAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _nextAt = null;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _pickNextDate(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Detalles adicionales de la aplicación',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Adjuntar foto/PDF (opcional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Adjuntar'),
                  ),
                ],
              ),
              if (_attachmentPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Adjunto: ${_attachmentPath!.split(Platform.pathSeparator).last}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                value: _createReminder,
                onChanged: (value) {
                  setState(() {
                    _createReminder = value;
                  });
                },
                title: const Text('Crear recordatorio'),
                subtitle: const Text(
                  'Recibirás una notificación para la próxima dosis.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _buildVaccineName() {
    if (_customNameController.text.trim().isNotEmpty) {
      return _customNameController.text.trim();
    }
    return _selectedVaccineName;
  }

  Future<void> _pickAppliedDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 10),
      lastDate: DateTime.now(),
      initialDate: _appliedAt,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _appliedAt = picked;
    });
  }

  Future<void> _pickNextDate(BuildContext context) async {
    final initial = _nextAt ?? _appliedAt.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      firstDate: _appliedAt,
      lastDate: DateTime(DateTime.now().year + 10),
      initialDate: initial,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _nextAt = picked;
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path;
    if (path == null) {
      return;
    }

    setState(() {
      _attachmentPath = path;
    });
  }

  Future<void> _save(int selectedPetId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final vaccineName = _buildVaccineName();
    if (vaccineName == null || vaccineName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre de la vacuna.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final healthRepo = ref.read(healthRepoProvider);
      final reminderRepo = ref.read(reminderRepoProvider);

      final event = HealthEvent(
        typeValue: HealthEventType.vaccine.index,
        title: vaccineName,
        notes: _buildNotesWithAttachment(),
        eventAt: _appliedAt,
        nextAt: _nextAt,
      );
      event.pet.targetId = selectedPetId;

      final eventId = healthRepo.addVaccine(event);

      if (_createReminder && _nextAt != null) {
        final reminder = Reminder(
          typeValue: HealthEventType.vaccine.index,
          title: 'Vacuna: $vaccineName',
          scheduledAt: _nextAt,
          relatedEventId: eventId,
        );
        reminder.pet.targetId = selectedPetId;
        final reminderId = reminderRepo.schedule(reminder);

        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.scheduleReminder(
          id: reminderId,
          title: 'Próxima vacuna',
          body: 'Le toca $vaccineName',
          scheduledAt: _nextAt!,
        );
      }

      if (!mounted) {
        return;
      }
      context.go('/');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _buildNotesWithAttachment() {
    final base = _notesController.text.trim();
    if (_attachmentPath == null) {
      return base.isEmpty ? null : base;
    }
    final fileName = _attachmentPath!.split(Platform.pathSeparator).last;
    final attachmentNote = 'Adjunto: $fileName ($_attachmentPath)';
    if (base.isEmpty) {
      return attachmentNote;
    }
    return '$base\n$attachmentNote';
  }
}
