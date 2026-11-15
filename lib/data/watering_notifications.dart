import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/models.dart';
import '../domain/watering_notification.dart';

/// Boundary around Android, also used to verify failure and launch races.
abstract interface class WateringNotificationClient {
  Future<void> initialize(void Function(String?) onTap);
  Future<NotificationAppLaunchDetails?> launchDetails();
  Future<bool> permission({bool request = false});
  Future<List<PendingNotificationRequest>> pending();
  Future<void> cancel(int id);
  Future<void> schedule({
    required int id,
    required String body,
    required tz.TZDateTime date,
    required String payload,
  });
}

class AndroidWateringNotificationClient implements WateringNotificationClient {
  AndroidWateringNotificationClient(this.plugin);
  final FlutterLocalNotificationsPlugin plugin;
  @override
  Future<void> initialize(void Function(String?) onTap) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<NotificationAppLaunchDetails?> launchDetails() =>
      plugin.getNotificationAppLaunchDetails();
  @override
  Future<bool> permission({bool request = false}) async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return (request
            ? await android?.requestNotificationsPermission()
            : await android?.areNotificationsEnabled()) ??
        false;
  }

  @override
  Future<List<PendingNotificationRequest>> pending() =>
      plugin.pendingNotificationRequests();
  @override
  Future<void> cancel(int id) => plugin.cancel(id: id);
  @override
  Future<void> schedule({
    required int id,
    required String body,
    required tz.TZDateTime date,
    required String payload,
  }) => plugin.zonedSchedule(
    id: id,
    title: 'Check watering',
    body: body,
    scheduledDate: date,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'watering_checks',
        'Watering checks',
        channelDescription: 'Reminders when a plant is due for a soil check',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: payload,
  );
}

/// One future reminder per plant. Saving the garden never depends on Android.
class WateringNotifications {
  WateringNotifications({
    FlutterLocalNotificationsPlugin? plugin,
    WateringNotificationClient? client,
    Future<String> Function()? timezone,
  }) : _client =
           client ??
           AndroidWateringNotificationClient(
             plugin ?? FlutterLocalNotificationsPlugin(),
           ),
       _timezone = timezone ?? _deviceTimezone;
  final WateringNotificationClient _client;
  final Future<String> Function() _timezone;
  final status = ValueNotifier<String?>(null);
  final permissionGranted = ValueNotifier<bool?>(null);
  Future<void>? _initializing;
  Future<void> _syncTail = Future.value();
  bool _ready = false;
  bool _readingLaunch = false;
  final Set<String?> _startupTaps = {};
  void Function(String?)? _onTap;
  final List<String?> _queued = [];
  static Future<String> _deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
  set onTap(void Function(String?)? handler) {
    _onTap = handler;
    if (handler != null) {
      final queued = List<String?>.of(_queued);
      _queued.clear();
      for (final payload in queued) {
        handler(payload);
      }
    }
  }

  void _receive(String? payload) {
    if (_readingLaunch && !_startupTaps.add(payload)) return;
    final handler = _onTap;
    if (handler == null) {
      _queued.add(payload);
    } else {
      handler(payload);
    }
  }

  Future<void> init() {
    if (_ready) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    try {
      tzdata.initializeTimeZones();
      _readingLaunch = true;
      await _client.initialize(_receive);
      final details = await _client.launchDetails();
      if (details?.didNotificationLaunchApp == true) {
        _receive(details?.notificationResponse?.payload);
      }
      _ready = true;
    } catch (_) {
      status.value =
          'Reminders are unavailable right now. Your checks are still saved in Bloom.';
    } finally {
      _readingLaunch = false;
      _startupTaps.clear();
    }
  }

  Future<bool> requestPermission() => _permission(request: true);
  Future<bool> hasPermission() => _permission();
  Future<bool> refreshPermission() => hasPermission();
  Future<bool> _permission({bool request = false}) async {
    await init();
    try {
      if (!_ready) return false;
      final granted = await _client.permission(request: request);
      permissionGranted.value = granted;
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<void> sync({
    required bool enabled,
    required List<Plant> plants,
    required List<WateringSchedule> schedules,
    DateTime? now,
  }) {
    final work = _syncTail.then((_) => _sync(enabled, plants, schedules, now));
    _syncTail = work.catchError((Object _) {});
    return work;
  }

  Future<void> _sync(
    bool enabled,
    List<Plant> plants,
    List<WateringSchedule> schedules,
    DateTime? now,
  ) async {
    try {
      await init();
      if (!_ready) return;
      final zone = await _timezone();
      tz.setLocalLocation(tz.getLocation(zone));
      final granted = await _client.permission();
      permissionGranted.value = granted;
      final current = now ?? DateTime.now();
      final pending = await _client.pending();
      final occupied = {for (final request in pending) request.id};
      final owned = pending
          .where((p) => WateringNotificationTarget.owns(p.payload))
          .toList();
      final keep = <int>{};
      final names = {for (final p in plants) p.id: p.name};
      final sorted = schedules.toList()
        ..sort((a, b) => a.plantId.compareTo(b.plantId));
      if (enabled && granted) {
        for (final schedule in sorted) {
          if (!schedule.nextCheckAt.isAfter(current)) continue;
          final name = names[schedule.plantId];
          if (name == null) continue;
          final candidates = owned.where(
            (p) =>
                WateringNotificationTarget.parse(p.payload)?.plantId ==
                    schedule.plantId &&
                !keep.contains(p.id),
          );
          final existing = candidates.isEmpty ? null : candidates.first;
          final id =
              existing?.id ??
              wateringNotificationId(schedule.plantId, occupied);
          occupied.add(id);
          keep.add(id);
          final payload = WateringNotificationTarget.encode(schedule, zone);
          final body = "Check $name's soil before deciding whether to water.";
          if (existing?.payload == payload &&
              existing?.title == 'Check watering' &&
              existing?.body == body) {
            continue;
          }
          await _client.schedule(
            id: id,
            body: body,
            date: tz.TZDateTime.from(schedule.nextCheckAt, tz.local),
            payload: payload,
          );
        }
      }
      for (final request in owned) {
        if (!keep.contains(request.id)) await _client.cancel(request.id);
      }
      status.value = enabled && !granted
          ? 'Notifications are off in Android settings. Your checks stay in Bloom.'
          : null;
    } catch (_) {
      status.value =
          "Your changes are saved. Reminders couldn't be updated; Bloom will retry when you reopen the app.";
    }
  }
}
