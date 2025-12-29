import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/features/reminders/domain/reminder.dart';
import 'package:pethouse/shared/utils/enums.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class HealthTabPage extends ConsumerWidget {
  const HealthTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petId = ref.watch(selectedPetIdProvider);
    final healthSummaryAsync = ref.watch(healthSummaryProvider(petId));
    final remindersAsync = ref.watch(remindersProvider(petId));

    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);

          return Scaffold(
            appBar: AppBar(title: const Text('Salud')),
            body: Column(
              children: [
                HealthAlertCard(
                  healthSummaryAsync: healthSummaryAsync,
                  remindersAsync: remindersAsync,
                ),
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Vacunas'),
                      Tab(text: 'Meds'),
                      Tab(text: 'Historial'),
                      Tab(text: 'Peso'),
                    ],
                  ),
                ),
                const Expanded(
                  child: TabBarView(
                    children: [
                      VaccinesTab(),
                      MedsTab(),
                      HistoryTab(),
                      WeightTab(),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                if (tabController.index != 0) {
                  return const SizedBox.shrink();
                }
                return FloatingActionButton.extended(
                  onPressed: () {
                    context.go('/health/vaccine/new');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar vacuna'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class HealthAlertCard extends StatelessWidget {
  const HealthAlertCard({
    super.key,
    required this.healthSummaryAsync,
    required this.remindersAsync,
  });

  final AsyncValue<HealthSummary> healthSummaryAsync;
  final AsyncValue<List<Reminder>> remindersAsync;

  @override
  Widget build(BuildContext context) {
    return healthSummaryAsync.when(
      data: (summary) {
        if (summary.upcomingVaccines.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final next = summary.upcomingVaccines.firstWhere(
          (event) => event.eventAt.isAfter(todayStart),
          orElse: () => summary.upcomingVaccines.first,
        );

        final diffDays = next.eventAt.difference(todayStart).inDays;

        if (diffDays < 0 || diffDays > 30) {
          return const SizedBox.shrink();
        }

        final label = diffDays == 0 ? 'vence hoy' : 'vence en $diffDays días';

        final hasReminder = remindersAsync.maybeWhen(
          data: (reminders) {
            for (final reminder in reminders) {
              if (reminder.relatedEventId == next.id && reminder.isEnabled) {
                return true;
              }
            }
            return false;
          },
          orElse: () => false,
        );

        final reminderLabel = hasReminder ? ' (recordatorio activo)' : '';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.1),
            child: ListTile(
              leading: Icon(
                Icons.vaccines,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Alerta de vacuna'),
              subtitle: Text('${next.title} $label$reminderLabel'),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class VaccinesTab extends ConsumerWidget {
  const VaccinesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPetId = ref.watch(selectedPetIdProvider);
    if (selectedPetId == null) {
      return const Center(
        child: Text('Selecciona una mascota para ver sus vacunas.'),
      );
    }

    final summaryAsync = ref.watch(healthSummaryProvider(selectedPetId));

    return summaryAsync.when(
      data: (summary) {
        final vaccines = summary.upcomingVaccines;

        if (vaccines.isEmpty) {
          return const Center(
            child: EmptyCard(
              title: 'Sin vacunas registradas',
              subtitle: 'Registra la primera vacuna de tu mascota.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = vaccines[index];
            final appliedAt = event.eventAt;
            final appliedLabel =
                '${appliedAt.day.toString().padLeft(2, '0')}/${appliedAt.month.toString().padLeft(2, '0')}/${appliedAt.year}';

            String nextLabel = 'Sin próxima fecha';
            String statusLabel = 'OK';
            IconData statusIcon = Icons.check_circle;
            Color? statusColor = Theme.of(context).colorScheme.primary;

            if (event.nextAt != null) {
              final nextAt = event.nextAt!;
              nextLabel =
                  '${nextAt.day.toString().padLeft(2, '0')}/${nextAt.month.toString().padLeft(2, '0')}/${nextAt.year}';

              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final diffDays = nextAt.difference(todayStart).inDays;

              if (diffDays <= 7) {
                statusLabel = 'Por vencer';
                statusIcon = Icons.warning_amber_rounded;
                statusColor = Colors.orange;
              }
            }

            return Card(
              child: ListTile(
                leading: const Icon(Icons.vaccines),
                title: Text(event.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aplicada: $appliedLabel'),
                    Text('Próxima: $nextLabel'),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: statusColor),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(event.title),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aplicada: $appliedLabel'),
                            Text('Próxima: $nextLabel'),
                            if (event.notes != null && event.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(event.notes!),
                              ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: vaccines.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('No se pudo cargar las vacunas.')),
    );
  }
}

class MedsTab extends ConsumerWidget {
  const MedsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPetId = ref.watch(selectedPetIdProvider);
    if (selectedPetId == null) {
      return const Center(
        child: Text('Selecciona una mascota para ver sus medicaciones.'),
      );
    }

    final summaryAsync = ref.watch(healthSummaryProvider(selectedPetId));

    return summaryAsync.when(
      data: (summary) {
        final meds = summary.medications;

        if (meds.isEmpty) {
          return const Center(
            child: EmptyCard(
              title: 'Sin medicaciones',
              subtitle: 'Registra medicaciones desde los eventos de salud.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = meds[index];
            final date = event.eventAt;
            final dateLabel =
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

            return Card(
              child: ListTile(
                leading: const Icon(Icons.medication),
                title: Text(event.title),
                subtitle: Text('Fecha: $dateLabel'),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: meds.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('No se pudo cargar las medicaciones.')),
    );
  }
}

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPetId = ref.watch(selectedPetIdProvider);
    if (selectedPetId == null) {
      return const Center(
        child: Text('Selecciona una mascota para ver su historial.'),
      );
    }

    final summaryAsync = ref.watch(healthSummaryProvider(selectedPetId));

    return summaryAsync.when(
      data: (summary) {
        final events = <HealthEvent>[
          ...summary.upcomingVaccines,
          ...summary.medications,
          ...summary.visits,
          ...summary.symptoms,
        ];

        if (events.isEmpty) {
          return const Center(
            child: EmptyCard(
              title: 'Sin historial',
              subtitle: 'Registra eventos de salud para tu mascota.',
            ),
          );
        }

        events.sort((a, b) => b.eventAt.compareTo(a.eventAt));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = events[index];
            final date = event.eventAt;
            final dateLabel =
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

            IconData icon;
            switch (event.type) {
              case HealthEventType.vaccine:
                icon = Icons.vaccines;
                break;
              case HealthEventType.medication:
                icon = Icons.medication;
                break;
              case HealthEventType.visit:
                icon = Icons.local_hospital;
                break;
              case HealthEventType.symptom:
                icon = Icons.sick;
                break;
            }

            return Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(event.title),
                subtitle: Text(dateLabel),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: events.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('No se pudo cargar el historial.')),
    );
  }
}

class WeightTab extends ConsumerWidget {
  const WeightTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPetId = ref.watch(selectedPetIdProvider);
    if (selectedPetId == null) {
      return const Center(
        child: Text('Selecciona una mascota para ver su peso.'),
      );
    }

    final weightsAsync = ref.watch(weightListProvider(selectedPetId));

    return weightsAsync.when(
      data: (weights) {
        if (weights.isEmpty) {
          return const Center(
            child: EmptyCard(
              title: 'Sin registros de peso',
              subtitle: 'Registra un peso desde el inicio.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final record = weights[index];
            final date = record.recordedAt;
            final dateLabel =
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

            return Card(
              child: ListTile(
                leading: const Icon(Icons.monitor_weight),
                title: Text('${record.weight.toStringAsFixed(1)} kg'),
                subtitle: Text(dateLabel),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: weights.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('No se pudo cargar el peso.')),
    );
  }
}
