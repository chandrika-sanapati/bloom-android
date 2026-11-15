import 'dart:async';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'soil_care.dart';
import 'reminder_time.dart';

/// Holds the garden and applies watering transitions in one persistence boundary.
class GardenStore extends ChangeNotifier {
  // `garden` remains public while `_garden` stays private state.
  GardenStore({required Garden garden, required this.persist, this.onChanged})
    : _garden = garden; // ignore: prefer_initializing_formals

  /// Runs after each saved change, so reminders stay in step with the garden.
  final Future<void> Function(Garden garden)? onChanged;

  Garden _garden;
  final Future<void> Function(Garden garden) persist;

  Garden get garden => _garden;

  Plant? plant(String id) {
    for (final plant in _garden.plants) {
      if (plant.id == id) return plant;
    }
    return null;
  }

  WateringSchedule? scheduleFor(String plantId) {
    for (final schedule in _garden.schedules) {
      if (schedule.plantId == plantId) return schedule;
    }
    return null;
  }

  List<WateringRecord> recordsFor(String plantId) {
    final records = _garden.records.where((r) => r.plantId == plantId).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return records;
  }

  DateTime? lastWatered(String plantId) {
    for (final record in recordsFor(plantId)) {
      if (record.outcome == WateringOutcome.watered) return record.recordedAt;
    }
    return null;
  }

  // Serialize whole transitions, including snapshot construction, so a second
  // screen cannot overwrite a preference or plant while a save is in flight.
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final work = _tail.then((_) => action());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<bool> addPlant(Plant value, {DateTime? lastWatered, DateTime? now}) =>
      _serial(() => _addPlant(value, lastWatered: lastWatered, now: now));
  Future<bool> savePlant(Plant value) => _serial(() => _savePlant(value));
  Future<bool> setLightPlacementAcknowledged(
    String id,
    bool value, {
    DateTime? now,
  }) => _serial(() => _setLightPlacementAcknowledged(id, value, now: now));
  Future<bool> deletePlant(String id) => _serial(() => _deletePlant(id));
  Future<bool> editNextCheck(String id, DateTime value, {DateTime? now}) =>
      _serial(() => _editNextCheck(id, value, now: now));
  Future<WateringRecord?> completeWateringCheck({
    required String plantId,
    required WateringOutcome outcome,
    required Soil soil,
    DateTime? now,
  }) => _serial(
    () => _completeWateringCheck(
      plantId: plantId,
      outcome: outcome,
      soil: soil,
      now: now,
    ),
  );
  Future<bool> setTaskNotifications(bool enabled) =>
      _serial(() => _setTaskNotifications(enabled));
  Future<bool> setReminderTime(int hour, int minute, {DateTime? now}) =>
      _serial(() => _setReminderTime(hour, minute, now: now));

  List<SoilCareEvent> soilCareFor(String plantId) =>
      _garden.soilCare.where((e) => e.plantId == plantId).toList()
        ..sort((a, b) {
          final date = b.occurredOn.compareTo(a.occurredOn);
          return date != 0 ? date : b.recordedAt.compareTo(a.recordedAt);
        });

  Future<bool> saveSoilCare(
    SoilCareEvent event, {
    bool updating = false,
    DateTime? now,
  }) => _serial(() async {
    if (plant(event.plantId) == null ||
        event.id.trim().isEmpty ||
        (event.product?.length ?? 0) > 120 ||
        (event.notes?.length ?? 0) > 500 ||
        event.actions.isEmpty ||
        calendarDay(
          event.occurredOn,
        ).isAfter(calendarDay(now ?? DateTime.now()))) {
      return false;
    }
    final matching = _garden.soilCare.where((e) => e.id == event.id);
    final original = matching.isEmpty ? null : matching.first;
    if ((updating && original == null) ||
        (original != null && original.plantId != event.plantId)) {
      return false;
    }
    if (original?.sameContentAs(event) == true) return true;
    final normalized = SoilCareEvent(
      id: event.id,
      plantId: event.plantId,
      occurredOn: DateTime(
        event.occurredOn.year,
        event.occurredOn.month,
        event.occurredOn.day,
      ),
      recordedAt: original?.recordedAt ?? event.recordedAt,
      actions: event.actions,
      product: event.actions.contains(SoilCareAction.nutrientsAdded)
          ? event.product
          : null,
      mixContainsFeed: event.actions.contains(SoilCareAction.mixRefreshed)
          ? event.mixContainsFeed
          : null,
      notes: event.notes,
    );
    return _commit(
      _garden.copyWith(
        soilCare: [
          for (final e in _garden.soilCare)
            if (e.id != event.id) e,
          normalized,
        ],
      ),
      syncNotifications: false,
    );
  });

  Future<bool> removeSoilCare(String plantId, String eventId) =>
      _serial(() async {
        if (!_garden.soilCare.any(
          (e) => e.id == eventId && e.plantId == plantId,
        )) {
          return false;
        }
        return _commit(
          _garden.copyWith(
            soilCare: _garden.soilCare
                .where((e) => !(e.id == eventId && e.plantId == plantId))
                .toList(),
          ),
          syncNotifications: false,
        );
      });

  /// Adds a plant and schedules its first check, as in `BloomStore.addPlant`.
  Future<bool> _addPlant(
    Plant plant, {
    DateTime? lastWatered,
    DateTime? now,
  }) async {
    if (plant.name.trim().isEmpty) return false;
    final species = PlantSpecies.forPlant(plant);
    final current = now ?? DateTime.now();
    if (lastWatered != null && lastWatered.isAfter(current)) return false;
    final reminder = _garden.preferences;

    final next = _firstCheck(
      lastWatered: lastWatered,
      intervalDays: species?.startingIntervalDays,
      now: current,
      hour: reminder.reminderHour,
      minute: reminder.reminderMinute,
    );

    final plants = [..._garden.plants, plant];
    final schedules = [
      ..._garden.schedules,
      if (species != null)
        WateringSchedule(
          plantId: plant.id,
          intervalDays: species.startingIntervalDays,
          nextCheckAt: next,
          createdAt: current,
          updatedAt: current,
          timeSource: CheckTimeSource.preference,
        ),
    ];
    return _commit(_garden.copyWith(plants: plants, schedules: schedules));
  }

  /// Renames or re-species an existing plant, or inserts it if missing.
  Future<bool> _savePlant(Plant plant) {
    final index = _garden.plants.indexWhere((p) => p.id == plant.id);
    final plants = [..._garden.plants];
    if (index >= 0) {
      plants[index] = plant;
    } else {
      plants.add(plant);
    }
    return _commit(_garden.copyWith(plants: plants));
  }

  /// Saves placement independently of watering and notification scheduling.
  Future<bool> _setLightPlacementAcknowledged(
    String plantId,
    bool acknowledged, {
    DateTime? now,
  }) {
    final current = plant(plantId);
    if (current == null) return Future.value(false);
    final guidance = PlantSpecies.forPlant(current)?.light;
    if (guidance == null) return Future.value(false);
    // Preserve the recorded time/version until the user explicitly clears it.
    if (acknowledged == (current.lightPlacement != null)) {
      return Future.value(true);
    }
    final updated = current.copyWith(
      lightPlacement: acknowledged
          ? LightPlacementAcknowledgment(
              acknowledgedAt: now ?? DateTime.now(),
              guidanceVersion: guidance.version,
            )
          : null,
      clearLightPlacement: !acknowledged,
    );
    return _commit(
      _garden.copyWith(
        plants: [
          for (final p in _garden.plants)
            if (p.id == plantId) updated else p,
        ],
      ),
      syncNotifications: false,
    );
  }

  /// Removes a plant with its schedule and history, as `deletePlant` does.
  Future<bool> _deletePlant(String id) => _commit(
    _garden.copyWith(
      plants: _garden.plants.where((p) => p.id != id).toList(),
      schedules: _garden.schedules.where((s) => s.plantId != id).toList(),
      records: _garden.records.where((r) => r.plantId != id).toList(),
      soilCare: _garden.soilCare.where((e) => e.plantId != id).toList(),
    ),
  );

  Future<bool> _editNextCheck(String plantId, DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final schedule = scheduleFor(plantId);
    if (schedule == null || date.isBefore(current)) return Future.value(false);
    return _commit(
      _garden.copyWith(
        schedules: [
          for (final s in _garden.schedules)
            if (s.plantId == plantId)
              s.copyWith(
                nextCheckAt: date,
                updatedAt: current,
                timeSource: CheckTimeSource.custom,
              )
            else
              s,
        ],
      ),
    );
  }

  /// Records a check and moves the next one, including the dry-soil follow-up.
  Future<WateringRecord?> _completeWateringCheck({
    required String plantId,
    required WateringOutcome outcome,
    required Soil soil,
    DateTime? now,
  }) async {
    final schedule = scheduleFor(plantId);
    final plantValue = plant(plantId);
    if (schedule == null || plantValue == null) return null;

    final current = now ?? DateTime.now();
    final followUpDays =
        outcome == WateringOutcome.checkedNotWatered && soil == Soil.dry
        ? WateringFollowUp.defaultDays
        : null;
    final intervalDays = outcome == WateringOutcome.watered
        ? schedule.intervalDays
        : (followUpDays ?? schedule.intervalDays);
    final next = reminderOnDay(
      DateTime.utc(current.year, current.month, current.day + intervalDays),
      _garden.preferences.reminderHour,
      _garden.preferences.reminderMinute,
    );

    final record = WateringRecord(
      id: newId(),
      plantId: plantId,
      scheduledFor: schedule.nextCheckAt,
      recordedAt: current,
      outcome: outcome,
      soil: soil,
    );

    final saved = await _commit(
      _garden.copyWith(
        records: [record, ..._garden.records],
        schedules: [
          for (final s in _garden.schedules)
            if (s.plantId == plantId)
              s.copyWith(
                nextCheckAt: next,
                updatedAt: current,
                timeSource: CheckTimeSource.preference,
              )
            else
              s,
        ],
      ),
    );
    return saved ? record : null;
  }

  Future<bool> _setTaskNotifications(bool enabled) => _commit(
    _garden.copyWith(
      preferences: _garden.preferences.copyWith(taskNotifications: enabled),
    ),
  );

  Future<bool> _setReminderTime(int hour, int minute, {DateTime? now}) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;
    final preferences = _garden.preferences;
    if (hour == preferences.reminderHour &&
        minute == preferences.reminderMinute) {
      return true;
    }
    final current = now ?? DateTime.now();
    final today = calendarDay(current);
    return _commit(
      _garden.copyWith(
        preferences: preferences.copyWith(
          reminderHour: hour,
          reminderMinute: minute,
        ),
        schedules: [
          for (final schedule in _garden.schedules)
            if (schedule.timeSource == CheckTimeSource.preference &&
                schedule.nextCheckAt.isAfter(current) &&
                calendarDay(schedule.nextCheckAt).isAfter(today))
              _retime(schedule, hour, minute, current)
            else
              schedule,
        ],
      ),
    );
  }

  WateringSchedule _retime(
    WateringSchedule schedule,
    int hour,
    int minute,
    DateTime now,
  ) {
    final next = reminderOnDay(schedule.nextCheckAt, hour, minute);
    return next.isAtSameMomentAs(schedule.nextCheckAt)
        ? schedule
        : schedule.copyWith(nextCheckAt: next, updatedAt: now);
  }

  /// First check: the reminder time on the day of the last watering plus the
  /// starting interval, or today at the reminder time when never watered.
  DateTime _firstCheck({
    required DateTime? lastWatered,
    required int? intervalDays,
    required DateTime now,
    required int hour,
    required int minute,
  }) {
    if (lastWatered != null && intervalDays != null) {
      return reminderOnDay(
        DateTime.utc(
          lastWatered.year,
          lastWatered.month,
          lastWatered.day + intervalDays,
        ),
        hour,
        minute,
      );
    }
    return reminderOnDay(now, hour, minute);
  }

  Future<bool> _commit(Garden next, {bool syncNotifications = true}) async {
    try {
      await persist(next);
    } catch (_) {
      return false;
    }
    _garden = next;
    notifyListeners();
    if (syncNotifications) {
      // The committed garden remains authoritative if an optional side effect
      // fails; notification status is reported by the notification service.
      try {
        await onChanged?.call(next);
      } catch (_) {
        /* Retry on resume. */
      }
    }
    return true;
  }
}
