import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/features/reminders/domain/reminder.dart';
import 'package:pethouse/shared/utils/enums.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class HealthTabPage extends ConsumerStatefulWidget {
  const HealthTabPage({super.key});

  @override
  ConsumerState<HealthTabPage> createState() => _HealthTabPageState();
}

class _HealthTabPageState extends ConsumerState<HealthTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(selectedPetIdProvider);
    final healthSummaryAsync = ref.watch(healthSummaryProvider(petId));
    final remindersAsync = ref.watch(remindersProvider(petId));

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
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Vacunas'),
                Tab(text: 'Meds'),
                Tab(text: 'Historial'),
                Tab(text: 'Peso'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                VaccinesTab(),
                MedsTab(),
                HistoryTab(),
                WeightTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget? _buildFab(BuildContext context) {
    switch (_tabController.index) {
      case 0: // Vaccines
        return FloatingActionButton.extended(
          onPressed: () => context.go('/health/vaccine/new'),
          icon: const Icon(Icons.add),
          label: const Text('Registrar vacuna'),
        );
      case 1: // Meds
        return FloatingActionButton.extended(
          onPressed: () => context.go('/health/med/new'),
          icon: const Icon(Icons.add),
          label: const Text('Añadir medicación'),
        );
      case 2: // History
        // User request didn't specify a button for history, but we can add a generic one
        // or leave it empty directly. Let's redirect to symptoms/notes as a generic history entry.
        return FloatingActionButton.extended(
          onPressed: () => context.go('/health/symptom/new'),
          icon: const Icon(Icons.note_add),
          label: const Text('Agregar registro'),
        );
      case 3: // Weight
        return FloatingActionButton.extended(
          onPressed: () => context.go('/weight/new'),
          icon: const Icon(Icons.add),
          label: const Text('Registrar peso'),
        );
      default:
        return null;
    }
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

        // Mini Graph Logic
        final reversedWeights = weights.reversed.toList();
        final spots = reversedWeights.map((w) => w.weight).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (spots.length > 1)
              SizedBox(
                height: 150,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomPaint(
                    painter: _SimpleLineChartPainter(
                      data: spots,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),

            if (spots.length > 1) const SizedBox(height: 20),

            ...weights.map((record) {
              final date = record.recordedAt;
              final dateLabel =
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.monitor_weight),
                  title: Text('${record.weight.toStringAsFixed(1)} kg'),
                  subtitle: Text(dateLabel),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('No se pudo cargar el peso.')),
    );
  }
}

class _SimpleLineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SimpleLineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal;

    // Add some padding to range
    final effectiveRange = range == 0 ? 1.0 : range;
    final bottomY = size.height;

    final stepX = size.width / (data.length - 1);

    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      // Normalize y: (val - min) / range -> 0..1. 1 is top, 0 is bottom.
      // But in canvas y=0 is top. So we want 1 -> topY, 0 -> bottomY.
      // y = bottomY - (normalized * height)
      final normalized = (data[i] - minVal) / effectiveRange;
      final y = bottomY - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
