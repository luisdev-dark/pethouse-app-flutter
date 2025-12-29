import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/features/reminders/domain/reminder.dart';
import 'package:pethouse/shared/services/notification_service.dart';
import 'package:pethouse/shared/utils/enums.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class HealthMedicationNewPage extends ConsumerStatefulWidget {
  const HealthMedicationNewPage({super.key});

  @override
  ConsumerState<HealthMedicationNewPage> createState() =>
      _HealthMedicationNewPageState();
}

class _HealthMedicationNewPageState
    extends ConsumerState<HealthMedicationNewPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _nextAt = DateTime.now();
  bool _createReminder = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPetId = ref.watch(selectedPetIdProvider);

    if (selectedPetId == null) {
      return const SimpleScaffold(
        title: 'Nuevo medicamento',
        body: 'Selecciona una mascota en Inicio.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo medicamento')),
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
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del medicamento',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingresa el nombre.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _doseController,
                decoration: const InputDecoration(
                  labelText: 'Dosis (opcional)',
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Próxima toma'),
                subtitle: Text(
                  '${_nextAt.day}/${_nextAt.month} ${_nextAt.hour}:${_nextAt.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickNextDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Crear recordatorio'),
                value: _createReminder,
                onChanged: (val) => setState(() => _createReminder = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickNextDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _nextAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextAt),
    );
    if (time == null) return;

    setState(() {
      _nextAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save(int petId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final healthRepo = ref.read(healthRepoProvider);
      final reminderRepo = ref.read(reminderRepoProvider);

      final event = HealthEvent(
        typeValue: HealthEventType.medication.index,
        title: _nameController.text.trim(),
        notes: '${_doseController.text.trim()}\n${_notesController.text.trim()}'
            .trim(),
        eventAt: DateTime.now(),
        nextAt: _nextAt,
      );
      event.pet.targetId = petId;
      final eventId = healthRepo.addVaccine(event); // Using generic add logic

      if (_createReminder) {
        final reminder = Reminder(
          typeValue: HealthEventType.medication.index,
          title: 'Medicación: ${_nameController.text.trim()}',
          scheduledAt: _nextAt,
          relatedEventId: eventId,
        );
        reminder.pet.targetId = petId;
        final reminderId = reminderRepo.schedule(reminder);

        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.scheduleReminder(
          id: reminderId,
          title: 'Medicamento',
          body: 'Hora de tomar ${_nameController.text.trim()}',
          scheduledAt: _nextAt,
        );
      }

      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
