import 'dart:convert';
import 'models.dart';

/// Only these owned formats may route a watering reminder.
class WateringNotificationTarget {
  const WateringNotificationTarget(this.plantId, {this.due, this.revision});
  static const prefix = 'bloom-watering:';
  static const legacyPrefix = 'bloom-watering-';
  final String plantId;
  final DateTime? due;
  final DateTime? revision;
  static bool owns(String? value) =>
      value != null &&
      (value.startsWith(prefix) || value.startsWith(legacyPrefix));
  static String encode(WateringSchedule schedule, String zone) =>
      '$prefix${jsonEncode({'v': 1, 'plant': schedule.plantId, 'due': schedule.nextCheckAt.toUtc().toIso8601String(), 'revision': schedule.updatedAt.toUtc().toIso8601String(), 'zone': zone})}';
  static WateringNotificationTarget? parse(String? value) {
    if (value == null || value.length > 2048) return null;
    if (value.startsWith(legacyPrefix)) {
      final id = value.substring(legacyPrefix.length);
      return _validId(id) ? WateringNotificationTarget(id) : null;
    }
    if (!value.startsWith(prefix)) return null;
    try {
      final data = jsonDecode(value.substring(prefix.length));
      if (data is! Map ||
          data['v'] != 1 ||
          !_validId(data['plant']) ||
          data['due'] is! String ||
          data['revision'] is! String) {
        return null;
      }
      final due = DateTime.tryParse(data['due'] as String);
      final revision = DateTime.tryParse(data['revision'] as String);
      if (due == null || revision == null || !due.isUtc || !revision.isUtc) {
        return null;
      }
      return WateringNotificationTarget(
        data['plant'] as String,
        due: due,
        revision: revision,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _validId(Object? id) =>
      id is String && id.trim().isNotEmpty && id.length <= 256;
}

enum ReminderDestination { check, detail, home }

class ReminderRoute {
  const ReminderRoute(this.destination, {this.plantId, this.schedule});
  final ReminderDestination destination;
  final String? plantId;
  final WateringSchedule? schedule;
  static ReminderRoute resolve(String? payload, Garden garden) {
    final target = WateringNotificationTarget.parse(payload);
    if (target == null || !garden.plants.any((p) => p.id == target.plantId)) {
      return const ReminderRoute(ReminderDestination.home);
    }
    final schedules = garden.schedules.where(
      (s) => s.plantId == target.plantId,
    );
    if (schedules.isEmpty) return const ReminderRoute(ReminderDestination.home);
    final schedule = schedules.first;
    final current =
        target.due?.isAtSameMomentAs(schedule.nextCheckAt) == true &&
        target.revision?.isAtSameMomentAs(schedule.updatedAt) == true;
    return ReminderRoute(
      current ? ReminderDestination.check : ReminderDestination.detail,
      plantId: target.plantId,
      schedule: schedule,
    );
  }
}

/// Stable across restarts, probing around occupied IDs (including unrelated ones).
int wateringNotificationId(String plantId, Set<int> occupied) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(plantId)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  var id = hash & 0x7fffffff;
  while (occupied.contains(id)) {
    id = (id + 1) & 0x7fffffff;
  }
  return id;
}
