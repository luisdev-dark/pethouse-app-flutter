import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/journal/domain/media_item.dart';
import 'package:pethouse/shared/utils/enums.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class JournalDetailPage extends ConsumerWidget {
  const JournalDetailPage({super.key, required this.entryId});

  final int? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entryId == null) {
      return const SimpleScaffold(
        title: 'Entrada',
        body: 'Entrada no encontrada.',
      );
    }

    final entryAsync = ref.watch(journalEntryProvider(entryId!));
    final mediaAsync = ref.watch(mediaListProvider);

    return entryAsync.when(
      data: (entry) {
        if (entry == null) {
          return const SimpleScaffold(
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
                Text(entry.text, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (entry.mood != null && entry.mood!.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.mood, size: 16),
                        label: Text(entry.mood!),
                      ),
                    ...entry.tags.map((tag) => Chip(label: Text('#$tag'))),
                    Chip(
                      avatar: const Icon(Icons.event, size: 16),
                      label: Text(dateLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Entrada')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Entrada')),
        body: const Center(child: Text('No se pudo cargar la entrada.')),
      ),
    );
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

    if (context.mounted) {
      context.go('/');
    }
  }
}
