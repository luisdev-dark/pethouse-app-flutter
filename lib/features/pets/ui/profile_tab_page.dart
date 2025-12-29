import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/shared/utils/enums.dart';

class ProfileTabPage extends ConsumerWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petAsync = ref.watch(selectedPetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
          ),
        ],
      ),
      body: petAsync.when(
        data: (pet) {
          if (pet == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No hay mascota seleccionada.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/pets/new'),
                    child: const Text('Crear nueva mascota'),
                  ),
                ],
              ),
            );
          }

          final wList = ref.watch(weightListProvider(pet.id)).asData?.value;
          final lastWeight = (wList != null && wList.isNotEmpty)
              ? wList.first.weight
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: pet.photoPath != null
                      ? FileImage(File(pet.photoPath!))
                      : null,
                  child: pet.photoPath == null
                      ? const Icon(Icons.pets, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  pet.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (pet.species.isNotEmpty)
                Center(
                  child: Text(
                    pet.species,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ProfileRow(
                        label: 'Raza',
                        value: pet.breed ?? 'No especificada',
                      ),
                      const Divider(),
                      ProfileRow(
                        label: 'Edad',
                        value: _calculateAge(pet.birthDate),
                      ),
                      const Divider(),
                      ProfileRow(
                        label: 'Peso actual',
                        value: lastWeight != null
                            ? '${lastWeight.toStringAsFixed(1)} kg'
                            : '--',
                      ),
                      const Divider(),
                      ProfileRow(
                        label: 'Sexo',
                        value: _sexToString(pet.sex ?? PetSex.unknown),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edición próximamente.')),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Editar mascota'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exportar resumen próximamente.'),
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Exportar resumen'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Error al cargar perfil.')),
      ),
    );
  }

  String _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 'Desconocida';
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final days = difference.inDays;
    if (days < 30) return '$days días';
    final months = (days / 30).floor();
    if (months < 12) return '$months meses';
    final years = (months / 12).floor();
    final remainingMonths = months % 12;
    if (remainingMonths > 0) return '$years años, $remainingMonths meses';
    return '$years años';
  }

  String _sexToString(PetSex sex) {
    switch (sex) {
      case PetSex.male:
        return 'Macho';
      case PetSex.female:
        return 'Hembra';
      default:
        return 'Desconocido';
    }
  }
}

class ProfileRow extends StatelessWidget {
  const ProfileRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
