import 'package:bloom/data/watering_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeNotificationClient implements WateringNotificationClient {
  void Function(String?)? tap;
  String? startupPayload;
  bool duplicateStartup = false;
  bool granted = true;
  bool fail = false;
  int permissionRequests = 0;
  int initializations = 0;
  final requests = <int, PendingNotificationRequest>{};
  final dates = <int, DateTime>{};
  final scheduled = <int>[];
  final cancelled = <int>[];
  @override
  Future<void> initialize(void Function(String?) onTap) async {
    initializations++;
    if (fail) throw StateError('Android unavailable');
    tap = onTap;
    if (duplicateStartup) onTap(startupPayload);
  }

  @override
  Future<NotificationAppLaunchDetails?> launchDetails() async =>
      startupPayload == null
      ? const NotificationAppLaunchDetails(false)
      : NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: startupPayload,
          ),
        );
  @override
  Future<bool> permission({bool request = false}) async {
    if (request) permissionRequests++;
    return granted;
  }

  @override
  Future<List<PendingNotificationRequest>> pending() async {
    if (fail) throw StateError('Android unavailable');
    return requests.values.toList();
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    requests.remove(id);
    dates.remove(id);
  }

  @override
  Future<void> schedule({
    required int id,
    required String body,
    required tz.TZDateTime date,
    required String payload,
  }) async {
    if (fail) throw StateError('Android unavailable');
    scheduled.add(id);
    dates[id] = date;
    requests[id] = PendingNotificationRequest(
      id,
      'Check watering',
      body,
      payload,
    );
  }
}
