import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/weight_record.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class WeightNewPage extends ConsumerStatefulWidget {
  const WeightNewPage({super.key});

  @override
  ConsumerState<WeightNewPage> createState() => _WeightNewPageState();
}

class _WeightNewPageState extends ConsumerState<WeightNewPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPetId = ref.watch(selectedPetIdProvider);

    if (selectedPetId == null) {
      return const SimpleScaffold(
        title: 'Nuevo peso',
        body: 'Selecciona una mascota en Inicio.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo peso')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Fecha'),
                  subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _date = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    suffixText: 'kg',
                  ),
                  validator: (v) {
                    if (v == null || double.tryParse(v) == null) {
                      return 'Ingresa un peso válido.';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(selectedPetId),
                    child: Text(_saving ? 'Guardando...' : 'Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(int petId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final weight = double.parse(_weightController.text);
    final record = WeightRecord(weight: weight, recordedAt: _date);
    record.pet.targetId = petId;

    ref.read(healthRepoProvider).addWeightRecord(record);

    if (mounted) {
      context.go('/health');
    }
  }
}
