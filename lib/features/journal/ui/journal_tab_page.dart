import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';
import 'package:pethouse/features/journal/domain/media_item.dart';
import 'package:pethouse/shared/utils/enums.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

enum _JournalSegment { all, photos, mood }

class JournalTabPage extends ConsumerStatefulWidget {
  const JournalTabPage({super.key});

  @override
  ConsumerState<JournalTabPage> createState() => _JournalTabPageState();
}

class _JournalTabPageState extends ConsumerState<JournalTabPage> {
  _JournalSegment _segment = _JournalSegment.all;
  String? _selectedTag;
  bool _filtersExpanded = false;
  String? _searchQuery;

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(selectedPetIdProvider);
    if (petId == null) {
      return const Center(
        child: Text('Selecciona una mascota en Inicio para ver su diario.'),
      );
    }

    final entriesAsync = ref.watch(
      journalFeedProvider(
        JournalFeedRequest(petId: petId, filters: _buildFilters()),
      ),
    );
    final mediaAsync = ref.watch(mediaListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diario'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _filtersExpanded = !_filtersExpanded;
              });
            },
            icon: Icon(
              _filtersExpanded ? Icons.filter_list_off : Icons.filter_list,
            ),
          ),
          IconButton(
            onPressed: _openSearchDialog,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/journal/new'),
        child: const Icon(Icons.add),
      ),
      body: entriesAsync.when(
        data: (entries) {
          final mediaItems = mediaAsync.asData?.value ?? <MediaItem>[];
          final mediaByEntry = <int, List<MediaItem>>{};
          for (final item in mediaItems) {
            mediaByEntry.putIfAbsent(item.entry.targetId, () => []).add(item);
          }

          final allTags = <String>{};
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
                    child: Column(
                      children: [
                        EmptyCard(
                          title: 'Aún no escribes nada',
                          subtitle: 'Crea la primera entrada para tu mascota.',
                        ),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            SuggestionChip('Hoy caminamos'),
                            SuggestionChip('Aprendió un truco'),
                            SuggestionChip('Estuvo raro hoy'),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
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
                                          (tag) => Chip(label: Text('#$tag')),
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
                  }, childCount: filteredEntries.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('No se pudo cargar el diario.')),
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
            decoration: const InputDecoration(hintText: 'Texto a buscar...'),
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
      _searchQuery = result == null || result.isEmpty
          ? null
          : result.toLowerCase();
    });
  }

  JournalFeedFilters? _buildFilters() {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return null;
    }
    return JournalFeedFilters(search: _searchQuery);
  }
}

class SuggestionChip extends StatelessWidget {
  final String label;
  const SuggestionChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        context.go(
          Uri(
            path: '/journal/new',
            queryParameters: {'text': label},
          ).toString(),
        );
      },
    );
  }
}
