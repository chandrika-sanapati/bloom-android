import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';

/// Schedules one future reminder per plant, mirroring the iOS
/// `syncWateringNotifications`: only future checks, never overdue bursts.
class WateringNotifications {
  WateringNotifications({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'watering_checks';
  static const _channelName = 'Watering checks';
  static const _idPrefix = 'bloom-watering-';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  /// Asks for permission. Returns false if the user declines.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    return granted;
  }

  Future<bool> hasPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Replaces all watering reminders with one per future check.
  Future<void> sync({
    required bool enabled,
    required List<Plant> plants,
    required List<WateringSchedule> schedules,
    DateTime? now,
  }) async {
    await init();
    final current = now ?? DateTime.now();

    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(_idPrefix) ?? false) {
        await _plugin.cancel(id: request.id);
      }
    }
    if (!enabled) return;

    final names = {for (final p in plants) p.id: p.name};
    for (final schedule in schedules) {
      if (!schedule.nextCheckAt.isAfter(current)) continue;
      final name = names[schedule.plantId];
      if (name == null) continue;

      await _plugin.zonedSchedule(
        id: _notificationId(schedule.plantId),
        title: 'Check watering',
        body: "Check $name's soil before deciding whether to water.",
        scheduledDate: tz.TZDateTime.from(schedule.nextCheckAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders when a plant is due for a soil check',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$_idPrefix${schedule.plantId}',
      );
    }
  }

  Future<void> cancelFor(String plantId) async {
    await init();
    await _plugin.cancel(id: _notificationId(plantId));
  }

  int _notificationId(String plantId) => plantId.hashCode & 0x7fffffff;

  @visibleForTesting
  static String idPrefix() => _idPrefix;
}
