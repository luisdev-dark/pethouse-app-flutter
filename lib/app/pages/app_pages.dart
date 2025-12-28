import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/features/health/domain/weight_record.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';
import 'package:pethouse/features/journal/domain/media_item.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/features/reminders/domain/reminder.dart';
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

enum _JournalSegment {
  all,
  photos,
  mood,
}

class JournalTabPage extends ConsumerStatefulWidget {
  const JournalTabPage({super.key});

  @override
  ConsumerState<JournalTabPage> createState() => _JournalTabPageState();
}

class _JournalTabPageState extends ConsumerState<JournalTabPage> {
  _JournalSegment _segment = _JournalSegment.all;
  String? _selectedTag;
  String? _searchQuery;
  bool _filtersExpanded = true;

  @override
  Widget build(BuildContext context) {
    final selectedPetId = ref.watch(selectedPetIdProvider);

    if (selectedPetId == null) {
      return const _SimpleScaffold(
        title: 'Diario',
        body: 'Selecciona una mascota en Inicio para ver el diario.',
      );
    }

    final journalAsync = ref.watch(
      journalFeedProvider(
        JournalFeedRequest(
          petId: selectedPetId,
          filters: _buildFilters(),
        ),
      ),
    );
    final mediaAsync = ref.watch(mediaListProvider);
    final selectedPetAsync = ref.watch(selectedPetProvider);

    return Scaffold(
      appBar: AppBar(
        title: selectedPetAsync.when(
          data: (pet) {
            if (pet == null) {
              return const Text('Diario');
            }
            return Text('Diario · ${pet.name}');
          },
          loading: () => const Text('Diario'),
          error: (_, __) => const Text('Diario'),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _filtersExpanded = !_filtersExpanded;
              });
            },
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
          ),
          IconButton(
            onPressed: _openSearchDialog,
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
          ),
        ],
      ),
      body: journalAsync.when(
        data: (entries) {
          final mediaItems = mediaAsync.asData?.value ?? const <MediaItem>[];

          final Map<int, List<MediaItem>> mediaByEntry =
              <int, List<MediaItem>>{};
          for (final item in mediaItems) {
            final entryId = item.entry.targetId;
            if (entryId == 0) {
              continue;
            }
            mediaByEntry.putIfAbsent(entryId, () => <MediaItem>[]).add(item);
          }

          final Set<String> allTags = <String>{};
          for (final entry in entries) {
            allTags.addAll(entry.tags);
          }

          bool hasPhoto(JournalEntry entry) {
            final items = mediaByEntry[entry.id];
            if (items == null || items.isEmpty) {
              return false;
            }
            for (final item in items) {
              if (item.type == MediaType.photo) {
                return true;
              }
            }
            return false;
          }

          String? firstPhotoPath(JournalEntry entry) {
            final items = mediaByEntry[entry.id];
            if (items == null || items.isEmpty) {
              return null;
            }
            for (final item in items) {
              if (item.type == MediaType.photo) {
                return item.path;
              }
            }
            return null;
          }

          final filteredEntries = entries.where((entry) {
            if (_segment == _JournalSegment.photos && !hasPhoto(entry)) {
              return false;
            }
            if (_segment == _JournalSegment.mood &&
                (entry.mood == null || entry.mood!.isEmpty)) {
              return false;
            }
            if (_selectedTag != null && _selectedTag!.isNotEmpty) {
              if (!entry.tags.contains(_selectedTag)) {
                return false;
              }
            }
            return true;
          }).toList();

          final filtersSliver = SliverToBoxAdapter(
            child: _filtersExpanded
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<_JournalSegment>(
                          segments: const <ButtonSegment<_JournalSegment>>[
                            ButtonSegment(
                              value: _JournalSegment.all,
                              label: Text('Todo'),
                              icon: Icon(Icons.format_align_left),
                            ),
                            ButtonSegment(
                              value: _JournalSegment.photos,
                              label: Text('Fotos'),
                              icon: Icon(Icons.photo),
                            ),
                            ButtonSegment(
                              value: _JournalSegment.mood,
                              label: Text('Ánimo'),
                              icon: Icon(Icons.mood),
                            ),
                          ],
                          selected: <_JournalSegment>{_segment},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _segment = selection.first;
                            });
                          },
                        ),
                        if (allTags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: allTags.map((tag) {
                              final bool selected = tag == _selectedTag;
                              return ChoiceChip(
                                label: Text('#$tag'),
                                selected: selected,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedTag = value ? tag : null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          );

          return CustomScrollView(
            slivers: [
              filtersSliver,
              if (filteredEntries.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: _EmptyCard(
                      title: 'Sin entradas',
                      subtitle: 'Crea una nueva entrada para tu mascota.',
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = filteredEntries[index];
                      final photoPath = firstPhotoPath(entry);
                      final date = entry.entryAt;
                      final dateLabel =
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.go('/journal/${entry.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (photoPath != null)
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.file(
                                      File(photoPath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (entry.mood != null &&
                                              entry.mood!.isNotEmpty)
                                            Chip(
                                              label: Text(entry.mood!),
                                              avatar: const Icon(
                                                Icons.mood,
                                                size: 16,
                                              ),
                                            ),
                                          ...entry.tags.map(
                                            (tag) => Chip(
                                              label: Text('#$tag'),
                                            ),
                                          ),
                                          Chip(
                                            avatar: const Icon(
                                              Icons.event,
                                              size: 16,
                                            ),
                                            label: Text(dateLabel),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filteredEntries.length,
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('No se pudo cargar el diario.'),
        ),
      ),
    );
  }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Buscar en el diario'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Texto a buscar...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _searchQuery =
          result == null || result.isEmpty ? null : result.toLowerCase();
    });
  }

  JournalFeedFilters? _buildFilters() {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return null;
    }
    return JournalFeedFilters(
      search: _searchQuery,
    );
  }
}

class HealthTabPage extends ConsumerStatefulWidget {
  const HealthTabPage({super.key});

  @override
  ConsumerState<HealthTabPage> createState() => _HealthTabPageState();
}

class _HealthTabPageState extends ConsumerState<HealthTabPage> {
  @override
  Widget build(BuildContext context) {
    final selectedPetId = ref.watch(selectedPetIdProvider);

    if (selectedPetId == null) {
      return const _SimpleScaffold(
        title: 'Salud',
        body: 'Selecciona una mascota en Inicio para ver su salud.',
      );
    }

    final healthSummaryAsync = ref.watch(healthSummaryProvider(selectedPetId));
    final remindersAsync = ref.watch(remindersProvider(selectedPetId));

    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) {
          final TabController? tabController =
              DefaultTabController.of(context);

          return Scaffold(
            appBar: AppBar(
              title: const Text('Salud'),
            ),
            body: Column(
              children: [
                _HealthAlertCard(
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
                      _VaccinesTab(),
                      _MedsTab(),
                      _HistoryTab(),
                      _WeightTab(),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: tabController == null
                ? null
                : AnimatedBuilder(
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

class _HealthAlertCard extends StatelessWidget {
  const _HealthAlertCard({
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

        final label = diffDays == 0
            ? 'vence hoy'
            : 'vence en $diffDays días';

        final hasReminder = remindersAsync.maybeWhen(
          data: (reminders) {
            for (final reminder in reminders) {
              if (reminder.relatedEventId == next.id &&
                  reminder.isEnabled) {
                return true;
              }
            }
            return false;
          },
          orElse: () => false,
        );

        final reminderLabel =
            hasReminder ? ' (recordatorio activo)' : '';

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withOpacity(0.1),
            child: ListTile(
              leading: Icon(
                Icons.vaccines,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Alerta de vacuna'),
              subtitle: Text(
                '${next.title} $label$reminderLabel',
              ),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _VaccinesTab extends ConsumerWidget {
  const _VaccinesTab();

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
            child: _EmptyCard(
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
            Color? statusColor =
                Theme.of(context).colorScheme.primary;

            if (event.nextAt != null) {
              final nextAt = event.nextAt!;
              nextLabel =
                  '${nextAt.day.toString().padLeft(2, '0')}/${nextAt.month.toString().padLeft(2, '0')}/${nextAt.year}';

              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final diffDays =
                  nextAt.difference(todayStart).inDays;

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
                    Icon(
                      statusIcon,
                      color: statusColor,
                    ),
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
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Aplicada: $appliedLabel'),
                            Text('Próxima: $nextLabel'),
                            if (event.notes != null &&
                                event.notes!.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8),
                                child: Text(event.notes!),
                              ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(),
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
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: vaccines.length,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const Center(
        child: Text('No se pudo cargar las vacunas.'),
      ),
    );
  }
}

class _MedsTab extends ConsumerWidget {
  const _MedsTab();

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
            child: _EmptyCard(
              title: 'Sin medicaciones',
              subtitle:
                  'Registra medicaciones desde los eventos de salud.',
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
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: meds.length,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const Center(
        child: Text('No se pudo cargar las medicaciones.'),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

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
            child: _EmptyCard(
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
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: events.length,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const Center(
        child: Text('No se pudo cargar el historial.'),
      ),
    );
  }
}

class _WeightTab extends ConsumerWidget {
  const _WeightTab();

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
            child: _EmptyCard(
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
                title:
                    Text('${record.weight.toStringAsFixed(1)} kg'),
                subtitle: Text(dateLabel),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: weights.length,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const Center(
        child: Text('No se pudo cargar el peso.'),
      ),
    );
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

class JournalNewPage extends _JournalEntryFormPage {
  const JournalNewPage({super.key}) : super(entryId: null);
}

class JournalEditPage extends _JournalEntryFormPage {
  const JournalEditPage({super.key, required int entryId})
    : super(entryId: entryId);
}

class _JournalEntryFormPage extends ConsumerStatefulWidget {
  const _JournalEntryFormPage({super.key, this.entryId});

  final int? entryId;

  @override
  ConsumerState<_JournalEntryFormPage> createState() =>
      _JournalEntryFormPageState();
}

class _JournalEntryFormPageState
    extends ConsumerState<_JournalEntryFormPage> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  DateTime _entryAt = DateTime.now();
  String? _mood;
  final Set<String> _selectedTags = <String>{};
  final List<String> _newPhotoPaths = <String>[];
  bool _saving = false;
  bool _initializedFromEntry = false;
  JournalEntry? _editingEntry;

  static const List<String> _availableMoods = <String>[
    '😄',
    '🙂',
    '😐',
    '😟',
    '🤒',
  ];

  static const List<String> _availableTags = <String>[
    'Paseo',
    'Comida',
    'Juego',
    'Truco',
    'Ansiedad',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.entryId != null;
    final mediaAsync = ref.watch(mediaListProvider);
    final mediaItems = mediaAsync.asData?.value ?? const <MediaItem>[];

    List<MediaItem> existingMedia = <MediaItem>[];
    if (isEditing && widget.entryId != null) {
      existingMedia = mediaItems
          .where((item) => item.entry.targetId == widget.entryId)
          .toList();
    }

    if (isEditing && !_initializedFromEntry && widget.entryId != null) {
      final entryAsync = ref.watch(journalEntryProvider(widget.entryId!));
      entryAsync.whenData((entry) {
        if (entry == null || _initializedFromEntry) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _initializedFromEntry) {
            return;
          }
          setState(() {
            _editingEntry = entry;
            _entryAt = entry.entryAt;
            _textController.text = entry.text;
            _mood = entry.mood;
            _selectedTags
              ..clear()
              ..addAll(entry.tags);
            _initializedFromEntry = true;
          });
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar entrada' : 'Nueva entrada'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _saveEntry(isEditing),
            child: Text(_saving ? 'Guardando...' : 'Guardar'),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha y hora'),
              subtitle: Text(
                '${_entryAt.day.toString().padLeft(2, '0')}/${_entryAt.month.toString().padLeft(2, '0')}/${_entryAt.year} ${_entryAt.hour.toString().padLeft(2, '0')}:${_entryAt.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.schedule),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Texto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ánimo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableMoods.map((mood) {
                final bool selected = _mood == mood;
                return ChoiceChip(
                  label: Text(mood),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _mood = selected ? null : mood;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableTags.map((tag) {
                final bool selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Fotos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Agregar foto'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPhotosGrid(existingMedia),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosGrid(List<MediaItem> existingMedia) {
    final allPaths = <String>[
      ...existingMedia
          .where((item) => item.type == MediaType.photo)
          .map((item) => item.path),
      ..._newPhotoPaths,
    ];

    if (allPaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allPaths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final path = allPaths[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Future<void> _pickDateTime() async {
    final initialDate = _entryAt;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(initialDate.year - 5),
      lastDate: DateTime(initialDate.year + 1),
      initialDate: initialDate,
    );
    if (pickedDate == null) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_entryAt),
    );
    if (pickedTime == null) {
      return;
    }
    setState(() {
      _entryAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
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
    final targetPath =
        '${directory.path}${separator}journal_$timestamp.$extension';
    final savedFile = await File(file.path).copy(targetPath);

    if (!mounted) {
      return;
    }
    setState(() {
      _newPhotoPaths.add(savedFile.path);
    });
  }

  Future<void> _saveEntry(bool isEditing) async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo en el diario.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final journalRepo = ref.read(journalRepoProvider);
      final mediaRepo = ref.read(mediaRepoProvider);

      int entryId;

      if (isEditing) {
        final existing = _editingEntry;
        if (existing == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo cargar la entrada.')),
          );
          setState(() {
            _saving = false;
          });
          return;
        }
        existing
          ..text = text
          ..mood = _mood
          ..tags = _selectedTags.toList()
          ..entryAt = _entryAt;
        entryId = journalRepo.saveEntry(existing);
      } else {
        final selectedPetId = ref.read(selectedPetIdProvider);
        if (selectedPetId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Selecciona una mascota en Inicio antes de crear una entrada.',
              ),
            ),
          );
          setState(() {
            _saving = false;
          });
          return;
        }

        final entry = JournalEntry(
          text: text,
          tags: _selectedTags.toList(),
          mood: _mood,
          entryAt: _entryAt,
        );
        entry.pet.targetId = selectedPetId;
        entryId = journalRepo.createEntry(entry);
      }

      if (_newPhotoPaths.isNotEmpty) {
        final mediaItems = _newPhotoPaths
            .map(
              (path) => MediaItem(
                typeValue: MediaType.photo.index,
                path: path,
              ),
            )
            .toList();
        mediaRepo.attachToEntry(entryId, mediaItems);
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

class JournalDetailPage extends ConsumerWidget {
  const JournalDetailPage({super.key, required this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entryId == null) {
      return const _SimpleScaffold(
        title: 'Entrada',
        body: 'Entrada no encontrada.',
      );
    }

    final entryAsync = ref.watch(journalEntryProvider(entryId!));
    final mediaAsync = ref.watch(mediaListProvider);

    return entryAsync.when(
      data: (entry) {
        if (entry == null) {
          return const _SimpleScaffold(
            title: 'Entrada',
            body: 'Entrada no encontrada.',
          );
        }

        final mediaItems = mediaAsync.asData?.value ?? const <MediaItem>[];
        final photos = mediaItems
            .where(
              (item) =>
                  item.entry.targetId == entry.id &&
                  item.type == MediaType.photo,
            )
            .toList();

        final date = entry.entryAt;
        final dateLabel =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Entrada'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  context.go('/journal/${entry.id}/edit');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, entry.id),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photos.isNotEmpty)
                  SizedBox(
                    height: 240,
                    child: PageView.builder(
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final item = photos[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(item.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (photos.isNotEmpty) const SizedBox(height: 16),
                Text(
                  entry.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (entry.mood != null && entry.mood!.isNotEmpty)
                      Chip(
                        avatar: const Icon(
                          Icons.mood,
                          size: 16,
                        ),
                        label: Text(entry.mood!),
                      ),
                    ...entry.tags.map(
                      (tag) => Chip(
                        label: Text('#$tag'),
                      ),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.event,
                        size: 16,
                      ),
                      label: Text(dateLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        appBar: AppBar(title: Text('Entrada')),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        appBar: AppBar(title: Text('Entrada')),
        body: Center(child: Text('No se pudo cargar la entrada.')),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  int entryId,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Borrar entrada'),
        content: const Text(
          '¿Seguro que quieres borrar esta entrada? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      );
    },
  );

  if (result != true) {
    return;
  }

  final journalRepo = ref.read(journalRepoProvider);
  final mediaRepo = ref.read(mediaRepoProvider);

  mediaRepo.deleteForEntry(entryId);
  journalRepo.deleteEntry(entryId);

  context.go('/');
}

class HealthVaccineNewPage extends ConsumerStatefulWidget {
  const HealthVaccineNewPage({super.key});

  @override
  ConsumerState<HealthVaccineNewPage> createState() =>
      _HealthVaccineNewPageState();
}

class _HealthVaccineNewPageState
    extends ConsumerState<HealthVaccineNewPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customNameController =
      TextEditingController();
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
      return const _SimpleScaffold(
        title: 'Nueva vacuna',
        body:
            'Selecciona una mascota en Inicio antes de registrar una vacuna.',
      );
    }

    final vaccineName = _buildVaccineName();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar vacuna'),
      ),
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
                value: _selectedVaccineName,
                decoration: const InputDecoration(
                  labelText: 'Vacuna',
                ),
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
    final fileName =
        _attachmentPath!.split(Platform.pathSeparator).last;
    final attachmentNote = 'Adjunto: $fileName ($_attachmentPath)';
    if (base.isEmpty) {
      return attachmentNote;
    }
    return '$base\n$attachmentNote';
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
