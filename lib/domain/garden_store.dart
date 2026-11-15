import 'package:flutter/foundation.dart';

import 'models.dart';

/// Holds the garden and applies watering transitions, mirroring the iOS store.
class GardenStore extends ChangeNotifier {
  GardenStore({
    required Garden garden,
    required this.persist,
    this.onChanged,
  }) : _garden = garden;

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

  /// Adds a plant and schedules its first check, as in `BloomStore.addPlant`.
  Future<bool> addPlant(Plant plant, {DateTime? lastWatered, DateTime? now}) async {
    if (plant.name.trim().isEmpty) return false;
    final species = PlantSpecies.forPlant(plant);
    final current = now ?? DateTime.now();
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
        ),
    ];
    return _commit(_garden.copyWith(plants: plants, schedules: schedules));
  }

  /// Renames or re-species an existing plant, or inserts it if missing.
  Future<bool> savePlant(Plant plant) {
    final index = _garden.plants.indexWhere((p) => p.id == plant.id);
    final plants = [..._garden.plants];
    if (index >= 0) {
      plants[index] = plant;
    } else {
      plants.add(plant);
    }
    return _commit(_garden.copyWith(plants: plants));
  }

  /// Removes a plant with its schedule and history, as `deletePlant` does.
  Future<bool> deletePlant(String id) => _commit(
        _garden.copyWith(
          plants: _garden.plants.where((p) => p.id != id).toList(),
          schedules: _garden.schedules.where((s) => s.plantId != id).toList(),
          records: _garden.records.where((r) => r.plantId != id).toList(),
        ),
      );

  Future<bool> editNextCheck(String plantId, DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final schedule = scheduleFor(plantId);
    if (schedule == null || date.isBefore(current)) return Future.value(false);
    return _commit(_garden.copyWith(
      schedules: [
        for (final s in _garden.schedules)
          if (s.plantId == plantId) s.copyWith(nextCheckAt: date, updatedAt: current) else s,
      ],
    ));
  }

  /// Records a check and moves the next one, including the dry-soil follow-up.
  Future<WateringRecord?> completeWateringCheck({
    required String plantId,
    required WateringOutcome outcome,
    required Soil soil,
    DateTime? now,
  }) async {
    final schedule = scheduleFor(plantId);
    final plantValue = plant(plantId);
    if (schedule == null || plantValue == null) return null;

    final current = now ?? DateTime.now();
    final followUpDays = outcome == WateringOutcome.checkedNotWatered && soil == Soil.dry
        ? WateringFollowUp.defaultDays
        : null;
    final intervalDays = outcome == WateringOutcome.watered
        ? schedule.intervalDays
        : (followUpDays ?? schedule.intervalDays);
    final next = current.add(Duration(days: intervalDays));

    final record = WateringRecord(
      id: newId(),
      plantId: plantId,
      scheduledFor: schedule.nextCheckAt,
      recordedAt: current,
      outcome: outcome,
      soil: soil,
    );

    final saved = await _commit(_garden.copyWith(
      records: [record, ..._garden.records],
      schedules: [
        for (final s in _garden.schedules)
          if (s.plantId == plantId) s.copyWith(nextCheckAt: next, updatedAt: current) else s,
      ],
    ));
    return saved ? record : null;
  }

  Future<bool> setTaskNotifications(bool enabled) => _commit(
        _garden.copyWith(
          preferences: _garden.preferences.copyWith(taskNotifications: enabled),
        ),
      );

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
      final base = lastWatered.add(Duration(days: intervalDays));
      return DateTime(base.year, base.month, base.day, hour, minute);
    }
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  Future<bool> _commit(Garden next) async {
    try {
      await persist(next);
    } catch (_) {
      return false;
    }
    _garden = next;
    notifyListeners();
    await onChanged?.call(next);
    return true;
  }
}
