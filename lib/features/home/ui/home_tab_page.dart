import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

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
                  const SectionTitle(title: 'Próximo recordatorio'),
                  const SizedBox(height: 12),
                  remindersAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const EmptyCard(
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
                    loading: () => const LoadingCard(),
                    error: (_, _) => const ErrorCard(),
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
                            return MiniCard(
                              title: 'Último peso',
                              value: latest == null
                                  ? '--'
                                  : '${latest.weight.toStringAsFixed(1)} kg',
                              onTap: () => context.go('/weight/new'),
                            );
                          },
                          loading: () => const MiniCard(
                            title: 'Último peso',
                            value: '...',
                          ),
                          error: (_, _) =>
                              const MiniCard(title: 'Último peso', value: '!'),
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
                            return MiniCard(
                              title: 'Próxima vacuna',
                              value: nextVaccine == null
                                  ? '--'
                                  : '${nextVaccine.eventAt.day}/${nextVaccine.eventAt.month}',
                              onTap: () => context.go('/health/vaccine/new'),
                            );
                          },
                          loading: () => const MiniCard(
                            title: 'Próxima vacuna',
                            value: '...',
                          ),
                          error: (_, _) => const MiniCard(
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
                            return MiniCard(
                              title: 'Última entrada',
                              value: latest == null ? '--' : 'Ver',
                              onTap: () {
                                if (latest != null) {
                                  context.go('/journal/${latest.id}');
                                }
                              },
                            );
                          },
                          loading: () => const MiniCard(
                            title: 'Última entrada',
                            value: '...',
                          ),
                          error: (_, _) => const MiniCard(
                            title: 'Última entrada',
                            value: '!',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle(title: 'Hoy'),
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
