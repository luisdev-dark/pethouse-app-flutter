import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';
import 'package:pethouse/features/journal/domain/media_item.dart';
import 'package:pethouse/shared/utils/enums.dart';

class JournalNewPage extends JournalEntryFormPage {
  const JournalNewPage({super.key}) : super(entryId: null);
}

class JournalEditPage extends JournalEntryFormPage {
  const JournalEditPage({super.key, required int entryId})
    : super(entryId: entryId);
}

class JournalEntryFormPage extends ConsumerStatefulWidget {
  const JournalEntryFormPage({super.key, this.entryId});

  final int? entryId;

  @override
  ConsumerState<JournalEntryFormPage> createState() =>
      _JournalEntryFormPageState();
}

class _JournalEntryFormPageState extends ConsumerState<JournalEntryFormPage> {
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
            Text('Ánimo', style: Theme.of(context).textTheme.titleMedium),
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
            Text('Tags', style: Theme.of(context).textTheme.titleMedium),
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
            Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
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
          child: Image.file(File(path), fit: BoxFit.cover),
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
    if (pickedDate == null || !mounted) {
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
              (path) => MediaItem(typeValue: MediaType.photo.index, path: path),
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
