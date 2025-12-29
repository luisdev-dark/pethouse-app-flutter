import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';

class PetSelectPage extends ConsumerWidget {
  const PetSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsync = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis mascotas')),
      body: petsAsync.when(
        data: (pets) {
          if (pets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No tienes mascotas registradas.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/pets/new'),
                    child: const Text('Crear mascota'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pet = pets[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: pet.photoPath != null
                        ? FileImage(File(pet.photoPath!))
                        : null,
                    child: pet.photoPath == null
                        ? const Icon(Icons.pets)
                        : null,
                  ),
                  title: Text(pet.name),
                  subtitle: Text(pet.species),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(selectedPetIdProvider.notifier).state = pet.id;
                    context.go('/');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Error al cargar mascotas.')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/pets/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
