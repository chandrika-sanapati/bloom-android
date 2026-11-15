import 'package:bloom/data/watering_notifications.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/watering_notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_notifications.dart';

void main() {
  final now = DateTime(2026, 11, 15, 10);
  final species = PlantSpecies.catalog.last;
  final plant = Plant(
    id: 'p',
    name: 'Pothos',
    species: species.scientific,
    asset: species.asset,
  );
  final schedule = WateringSchedule(
    plantId: 'p',
    intervalDays: 14,
    nextCheckAt: DateTime(2026, 11, 17, 9),
    createdAt: now,
    updatedAt: now,
    timeSource: CheckTimeSource.preference,
  );
  final garden = Garden(plants: [plant], schedules: [schedule]);

  test(
    'resolve current, overdue, stale, completed, legacy, removed and invalid payloads',
    () {
      final payload = WateringNotificationTarget.encode(
        schedule,
        'Europe/Berlin',
      );
      expect(
        ReminderRoute.resolve(payload, garden).destination,
        ReminderDestination.check,
      );
      // Resolution deliberately does not reject a still-current overdue task.
      final overdue = schedule.copyWith(
        nextCheckAt: now.subtract(const Duration(days: 1)),
      );
      expect(
        ReminderRoute.resolve(
          WateringNotificationTarget.encode(overdue, 'UTC'),
          garden.copyWith(schedules: [overdue]),
        ).destination,
        ReminderDestination.check,
      );
      expect(
        ReminderRoute.resolve(
          payload,
          garden.copyWith(
            schedules: [
              schedule.copyWith(updatedAt: now.add(const Duration(seconds: 1))),
            ],
          ),
        ).destination,
        ReminderDestination.detail,
      );
      expect(
        ReminderRoute.resolve(
          payload,
          garden.copyWith(
            schedules: [schedule.copyWith(nextCheckAt: DateTime(2026, 12, 1))],
          ),
        ).destination,
        ReminderDestination.detail,
      );
      expect(
        ReminderRoute.resolve('bloom-watering-p', garden).destination,
        ReminderDestination.detail,
      );
      expect(
        ReminderRoute.resolve(payload, const Garden()).destination,
        ReminderDestination.home,
      );
      expect(
        ReminderRoute.resolve(
          payload,
          garden.copyWith(schedules: []),
        ).destination,
        ReminderDestination.home,
      );
      for (final invalid in [
        null,
        '',
        '/plant/p',
        'bloom-watering:',
        'bloom-watering- ',
        'bloom-watering:{"v":2}',
        'x' * 3000,
      ]) {
        expect(
          ReminderRoute.resolve(invalid, garden).destination,
          ReminderDestination.home,
        );
      }
    },
  );

  test(
    'bounded deterministic IDs probe around collisions and unrelated requests',
    () {
      final id = wateringNotificationId('p', {});
      expect(wateringNotificationId('p', {}), id);
      expect(id, inInclusiveRange(0, 0x7fffffff));
      expect(wateringNotificationId('p', {id}), (id + 1) & 0x7fffffff);
    },
  );

  test(
    'incremental sync changes only eligible future automatic request, keeps protected trigger times',
    () async {
      final client = FakeNotificationClient();
      final notifications = WateringNotifications(
        client: client,
        timezone: () async => 'UTC',
      );
      final schedules = [
        schedule,
        schedule.copyWith(
          nextCheckAt: DateTime(2026, 11, 15, 23),
          timeSource: CheckTimeSource.preference,
        ),
      ];
      final today = WateringSchedule(
        plantId: 'today',
        intervalDays: 14,
        nextCheckAt: schedules[1].nextCheckAt,
        createdAt: now,
        updatedAt: now,
        timeSource: CheckTimeSource.preference,
      );
      final custom = WateringSchedule(
        plantId: 'custom',
        intervalDays: 14,
        nextCheckAt: schedule.nextCheckAt,
        createdAt: now,
        updatedAt: now,
        timeSource: CheckTimeSource.custom,
      );
      final legacy = WateringSchedule(
        plantId: 'legacy',
        intervalDays: 14,
        nextCheckAt: schedule.nextCheckAt,
        createdAt: now,
        updatedAt: now,
      );
      final plants = [
        plant,
        for (final id in ['today', 'custom', 'legacy'])
          plant.copyWith(name: id),
      ];
      // copyWith intentionally retains IDs, construct distinct fixture plants.
      final distinct = [
        plant,
        for (final p in plants.skip(1))
          Plant(id: p.name, name: p.name, species: p.species, asset: p.asset),
      ];
      final store = GardenStore(
        garden: garden.copyWith(
          plants: distinct,
          schedules: [schedule, today, custom, legacy],
        ),
        persist: (_) async {},
      );
      Future<void> sync() => notifications.sync(
        enabled: true,
        plants: store.garden.plants,
        schedules: store.garden.schedules,
        now: now,
      );
      await sync();
      expect(client.requests, hasLength(4));
      final before = Map<int, DateTime>.of(client.dates);
      client.scheduled.clear();
      await sync();
      expect(client.scheduled, isEmpty);
      await store.setReminderTime(18, 30, now: now);
      await sync();
      expect(client.scheduled, hasLength(1));
      for (final entry in before.entries) {
        if (!client.scheduled.contains(entry.key)) {
          expect(client.dates[entry.key], entry.value);
        }
      }
      expect(client.cancelled, isEmpty);
      expect(client.permissionRequests, 0);
    },
  );

  test(
    'legacy upgrade preserves timestamp/ID, cleans duplicates, never schedules overdue or unrelated tasks',
    () async {
      final client = FakeNotificationClient();
      client.requests[7] = const PendingNotificationRequest(
        7,
        'Check watering',
        'old',
        'bloom-watering-p',
      );
      client.requests[8] = const PendingNotificationRequest(
        8,
        'Check watering',
        'old',
        'bloom-watering-p',
      );
      client.requests[9] = const PendingNotificationRequest(
        9,
        'Other',
        'keep',
        'unrelated',
      );
      final notifications = WateringNotifications(
        client: client,
        timezone: () async => 'UTC',
      );
      await notifications.sync(
        enabled: true,
        plants: [plant],
        schedules: [schedule],
        now: now,
      );
      expect(client.scheduled, [7]);
      expect(client.cancelled, [8]);
      expect(client.dates[7]!.isAtSameMomentAs(schedule.nextCheckAt), isTrue);
      await notifications.sync(
        enabled: true,
        plants: [plant],
        schedules: [schedule],
        now: DateTime(2026, 12, 1),
      );
      expect(client.requests.keys, [9]);
      await notifications.sync(
        enabled: false,
        plants: [plant],
        schedules: [schedule],
        now: now,
      );
      expect(client.requests.keys, [9]);
    },
  );

  test(
    'timezone refresh keeps instant while replacing zone metadata; permission is optional',
    () async {
      final client = FakeNotificationClient();
      var zone = 'UTC';
      final notifications = WateringNotifications(
        client: client,
        timezone: () async => zone,
      );
      Future<void> sync() => notifications.sync(
        enabled: true,
        plants: [plant],
        schedules: [schedule],
        now: now,
      );
      await sync();
      final date = client.dates.values.single;
      zone = 'Europe/Berlin';
      await sync();
      expect(client.scheduled, hasLength(2));
      expect(client.dates.values.single.isAtSameMomentAs(date), isTrue);
      client.granted = false;
      await sync();
      expect(client.requests, isEmpty);
      expect(notifications.status.value, contains('Android settings'));
      expect(client.permissionRequests, 0);
    },
  );

  test(
    'cold launch and callback duplicate once; normal init/resume never replays; later tap still delivered',
    () async {
      final client = FakeNotificationClient()
        ..startupPayload = 'bloom-watering-p'
        ..duplicateStartup = true;
      final notifications = WateringNotifications(
        client: client,
        timezone: () async => 'UTC',
      );
      final events = <String?>[];
      await Future.wait([notifications.init(), notifications.init()]);
      notifications.onTap = events.add;
      expect(events, ['bloom-watering-p']);
      await notifications.init();
      expect(client.initializations, 1);
      client.tap!('bloom-watering-p');
      expect(events, hasLength(2));
    },
  );

  test(
    'Android failures never throw or prevent retry and future sync',
    () async {
      final client = FakeNotificationClient()..fail = true;
      final notifications = WateringNotifications(
        client: client,
        timezone: () async => 'UTC',
      );
      await notifications.sync(
        enabled: true,
        plants: [plant],
        schedules: [schedule],
        now: now,
      );
      expect(notifications.status.value, isNotNull);
      client.fail = false;
      await notifications.sync(
        enabled: true,
        plants: [plant],
        schedules: [schedule],
        now: now,
      );
      expect(client.requests, hasLength(1));
      expect(notifications.status.value, isNull);
      client.fail = true;
      await notifications.sync(
        enabled: false,
        plants: [plant],
        schedules: [schedule],
        now: now,
      );
      expect(notifications.status.value, contains('saved'));
    },
  );
}
