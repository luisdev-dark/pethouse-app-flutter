import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:objectbox/objectbox.dart';
import 'package:pethouse/features/health/data/health_repo.dart';
import 'package:pethouse/features/health/domain/health_event.dart';
import 'package:pethouse/features/health/domain/weight_record.dart';
import 'package:pethouse/features/journal/data/journal_repo.dart';
import 'package:pethouse/features/journal/data/media_repo.dart';
import 'package:pethouse/features/journal/domain/journal_entry.dart';
import 'package:pethouse/features/journal/domain/media_item.dart';
import 'package:pethouse/features/pets/data/pet_repo.dart';
import 'package:pethouse/features/pets/domain/pet.dart';
import 'package:pethouse/features/reminders/data/reminder_repo.dart';
import 'package:pethouse/features/reminders/domain/reminder.dart';
import 'package:pethouse/shared/utils/enums.dart';

final selectedPetIdProvider = StateProvider<int?>((ref) => null);

final objectBoxStoreProvider = Provider<Store>((ref) {
  throw StateError('Store not initialized. Override objectBoxStoreProvider.');
});

final petRepoProvider = Provider<PetRepository>((ref) {
  return PetRepository(ref.watch(objectBoxStoreProvider));
});

final journalRepoProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(ref.watch(objectBoxStoreProvider));
});

final healthRepoProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(objectBoxStoreProvider));
});

final reminderRepoProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(objectBoxStoreProvider));
});

final mediaRepoProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(ref.watch(objectBoxStoreProvider));
});

final petsProvider = StreamProvider<List<Pet>>((ref) {
  return ref.watch(petRepoProvider).watchAll();
});

final selectedPetProvider = StreamProvider<Pet?>((ref) {
  final selectedId = ref.watch(selectedPetIdProvider);
  if (selectedId == null) {
    return Stream<Pet?>.value(null);
  }
  return ref.watch(petRepoProvider).watchById(selectedId);
});

final todayDashboardProvider = StreamProvider.family<TodayDashboard, int?>((
  ref,
  petId,
) {
  if (petId == null) {
    return Stream<TodayDashboard>.value(const TodayDashboard.empty());
  }

  final journalStream = ref.watch(journalRepoProvider).watchAll();
  final healthStream = ref.watch(healthRepoProvider).watchEvents();
  final reminderStream = ref.watch(reminderRepoProvider).watchAll();

  final controller = StreamController<TodayDashboard>();
  List<JournalEntry>? journals;
  List<HealthEvent>? events;
  List<Reminder>? reminders;

  void emitIfReady() {
    if (journals == null || events == null || reminders == null) {
      return;
    }
    controller.add(
      _buildDashboard(
        petId: petId,
        journals: journals!,
        events: events!,
        reminders: reminders!,
      ),
    );
  }

  final journalSub = journalStream.listen((items) {
    journals = items;
    emitIfReady();
  });
  final healthSub = healthStream.listen((items) {
    events = items;
    emitIfReady();
  });
  final reminderSub = reminderStream.listen((items) {
    reminders = items;
    emitIfReady();
  });

  controller.onCancel = () {
    journalSub.cancel();
    healthSub.cancel();
    reminderSub.cancel();
  };

  return controller.stream;
});

final journalFeedProvider =
    StreamProvider.family<List<JournalEntry>, JournalFeedRequest>((
      ref,
      request,
    ) {
      return ref.watch(journalRepoProvider).watchAll().map((entries) {
        final filtered = entries.where((entry) {
          if (entry.pet.targetId != request.petId) {
            return false;
          }
          final filters = request.filters;
          if (filters == null) {
            return true;
          }
          if (filters.mood != null && entry.mood != filters.mood) {
            return false;
          }
          if (filters.tag != null && !entry.tags.contains(filters.tag)) {
            return false;
          }
          if (filters.search != null && filters.search!.isNotEmpty) {
            final query = filters.search!.toLowerCase();
            if (!entry.text.toLowerCase().contains(query)) {
              return false;
            }
          }
          return true;
        }).toList();

        filtered.sort((a, b) => b.entryAt.compareTo(a.entryAt));
        return filtered;
      });
    });

final healthSummaryProvider = StreamProvider.family<HealthSummary, int?>((
  ref,
  petId,
) {
  if (petId == null) {
    return Stream<HealthSummary>.value(const HealthSummary.empty());
  }
  return ref.watch(healthRepoProvider).watchEvents().map((events) {
    final petEvents = events.where((event) => event.pet.targetId == petId);
    final upcomingVaccines = <HealthEvent>[];
    final medications = <HealthEvent>[];
    final visits = <HealthEvent>[];
    final symptoms = <HealthEvent>[];

    for (final event in petEvents) {
      switch (event.type) {
        case HealthEventType.vaccine:
          upcomingVaccines.add(event);
          break;
        case HealthEventType.medication:
          medications.add(event);
          break;
        case HealthEventType.visit:
          visits.add(event);
          break;
        case HealthEventType.symptom:
          symptoms.add(event);
          break;
      }
    }

    upcomingVaccines.sort((a, b) => a.eventAt.compareTo(b.eventAt));

    return HealthSummary(
      upcomingVaccines: upcomingVaccines,
      medications: medications,
      visits: visits,
      symptoms: symptoms,
    );
  });
});

final weightListProvider = StreamProvider.family<List<WeightRecord>, int?>((
  ref,
  petId,
) {
  if (petId == null) {
    return Stream<List<WeightRecord>>.value(const <WeightRecord>[]);
  }
  return ref.watch(healthRepoProvider).watchWeights().map((weights) {
    final filtered = weights
        .where((entry) => entry.pet.targetId == petId)
        .toList();
    filtered.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return filtered;
  });
});

final remindersProvider = StreamProvider.family<List<Reminder>, int?>((
  ref,
  petId,
) {
  if (petId == null) {
    return Stream<List<Reminder>>.value(const <Reminder>[]);
  }
  return ref.watch(reminderRepoProvider).watchAll().map((reminders) {
    final filtered = reminders
        .where((item) => item.pet.targetId == petId)
        .toList();
    filtered.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return filtered;
  });
});

final mediaListProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(mediaRepoProvider).watchAll();
});

class JournalFeedFilters {
  const JournalFeedFilters({this.search, this.tag, this.mood});

  final String? search;
  final String? tag;
  final String? mood;

  @override
  bool operator ==(Object other) {
    return other is JournalFeedFilters &&
        other.search == search &&
        other.tag == tag &&
        other.mood == mood;
  }

  @override
  int get hashCode => Object.hash(search, tag, mood);
}

class JournalFeedRequest {
  const JournalFeedRequest({required this.petId, this.filters});

  final int petId;
  final JournalFeedFilters? filters;

  @override
  bool operator ==(Object other) {
    return other is JournalFeedRequest &&
        other.petId == petId &&
        other.filters == filters;
  }

  @override
  int get hashCode => Object.hash(petId, filters);
}

class HealthSummary {
  const HealthSummary({
    required this.upcomingVaccines,
    required this.medications,
    required this.visits,
    required this.symptoms,
  });

  const HealthSummary.empty()
    : upcomingVaccines = const <HealthEvent>[],
      medications = const <HealthEvent>[],
      visits = const <HealthEvent>[],
      symptoms = const <HealthEvent>[];

  final List<HealthEvent> upcomingVaccines;
  final List<HealthEvent> medications;
  final List<HealthEvent> visits;
  final List<HealthEvent> symptoms;
}

class TodayDashboard {
  const TodayDashboard({
    required this.journalCount,
    required this.upcomingVaccines,
    required this.activeReminders,
  });

  const TodayDashboard.empty()
    : journalCount = 0,
      upcomingVaccines = 0,
      activeReminders = 0;

  final int journalCount;
  final int upcomingVaccines;
  final int activeReminders;
}

TodayDashboard _buildDashboard({
  required int petId,
  required List<JournalEntry> journals,
  required List<HealthEvent> events,
  required List<Reminder> reminders,
}) {
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final tomorrow = todayStart.add(const Duration(days: 1));

  final journalCount = journals.where((entry) {
    if (entry.pet.targetId != petId) {
      return false;
    }
    return entry.entryAt.isAfter(todayStart) &&
        entry.entryAt.isBefore(tomorrow);
  }).length;

  final upcomingVaccines = events.where((event) {
    if (event.pet.targetId != petId) {
      return false;
    }
    return event.type == HealthEventType.vaccine &&
        event.eventAt.isAfter(todayStart);
  }).length;

  final activeReminders = reminders.where((reminder) {
    return reminder.pet.targetId == petId && reminder.isEnabled;
  }).length;

  return TodayDashboard(
    journalCount: journalCount,
    upcomingVaccines: upcomingVaccines,
    activeReminders: activeReminders,
  );
}
