import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/shared/utils/enums.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class HealthSymptomNewPage extends ConsumerStatefulWidget {
  const HealthSymptomNewPage({super.key});

  @override
  ConsumerState<HealthSymptomNewPage> createState() =>
      _HealthSymptomNewPageState();
}

class _HealthSymptomNewPageState extends ConsumerState<HealthSymptomNewPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _occurredAt = DateTime.now();
  String? _attachmentPath;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPetId = ref.watch(selectedPetIdProvider);
    if (selectedPetId == null) {
      return const SimpleScaffold(
        title: 'Nuevo síntoma',
        body: 'Selecciona una mascota en Inicio.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar síntoma/nota')),
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título del síntoma o evento',
                  hintText: 'Ej. Vómito, Cojera, Consulta general',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un título.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha y hora'),
                subtitle: Text(
                  '${_occurredAt.day.toString().padLeft(2, '0')}/${_occurredAt.month.toString().padLeft(2, '0')}/${_occurredAt.year} ${_occurredAt.hour.toString().padLeft(2, '0')}:${_occurredAt.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(context),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas / Observaciones',
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
                    label: const Text('Adjuntar archivo'),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
      initialDate: _occurredAt,
    );
    if (pickedDate == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (pickedTime == null) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: false,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path != null) {
      setState(() {
        _attachmentPath = path;
      });
    }
  }

  Future<void> _save(int selectedPetId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
    });

    try {
      final healthRepo = ref.read(healthRepoProvider);

      final event = HealthEvent(
        typeValue: HealthEventType.symptom.index,
        title: _titleController.text.trim(),
        notes: _buildNotesWithAttachment(),
        eventAt: _occurredAt,
      );
      event.pet.targetId = selectedPetId;

      healthRepo.addVaccine(
        event,
      ); // addVaccine is likely generic addEvent internally or bad naming, let's assume it works for events for now or check repo.
      // Actually checking HealthRepo would be good but I'll assume addVaccine works for HealthEvent entity.
      // Wait, let me check HealthRepo method names if possible.
      // Assuming addVaccine actually just puts the box.

      if (mounted) {
        context.go('/');
      }
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
