import 'dart:async';
import 'dart:convert';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/reminder_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  final now = DateTime(2026, 11, 15, 10);
  final species = PlantSpecies.catalog[3];
  Plant plant(String id) => Plant(
    id: id,
    name: id,
    species: species.scientific,
    asset: species.asset,
  );
  WateringSchedule schedule(String id, DateTime due, CheckTimeSource source) =>
      WateringSchedule(
        plantId: id,
        intervalDays: 14,
        nextCheckAt: due,
        createdAt: now,
        updatedAt: now,
        timeSource: source,
      );

  test('migration preserves unknown provenance and valid preference data', () {
    final original = schedule(
      'p',
      DateTime(2026, 12, 1, 8, 45),
      CheckTimeSource.custom,
    );
    final old = original.toJson()..remove('timeSource');
    expect(WateringSchedule.fromJson(old).timeSource, CheckTimeSource.legacy);
    expect(
      WateringSchedule.fromJson({...old, 'timeSource': 'future'}).timeSource,
      CheckTimeSource.legacy,
    );
    expect(
      WateringSchedule.fromJson(original.toJson()).timeSource,
      CheckTimeSource.custom,
    );
    for (final invalid in [null, -1, 24, '9', 2.5]) {
      expect(
        AppPreferences.fromJson({'reminderHour': invalid}).reminderHour,
        9,
      );
    }
    expect(AppPreferences.fromJson({'reminderMinute': 60}).reminderMinute, 0);
    expect(
      AppPreferences.fromJson({
        'reminderHour': 18,
        'reminderMinute': 30,
      }).reminderHour,
      18,
    );
  });

  test(
    'time and automatic future checks commit together; all protected checks stay exact',
    () async {
      final schedules = [
        schedule('auto', DateTime(2026, 11, 17, 9), CheckTimeSource.preference),
        schedule(
          'custom-equal',
          DateTime(2026, 11, 17, 9),
          CheckTimeSource.custom,
        ),
        schedule(
          'legacy',
          DateTime(2026, 11, 18, 12, 13),
          CheckTimeSource.legacy,
        ),
        schedule(
          'today-future',
          DateTime(2026, 11, 15, 23),
          CheckTimeSource.preference,
        ),
        schedule(
          'today-past',
          DateTime(2026, 11, 15, 8),
          CheckTimeSource.preference,
        ),
        schedule(
          'overdue',
          DateTime(2026, 11, 14, 9),
          CheckTimeSource.preference,
        ),
      ];
      final writes = <Garden>[];
      final store = GardenStore(
        garden: Garden(
          plants: schedules.map((s) => plant(s.plantId)).toList(),
          schedules: schedules,
        ),
        persist: (g) async => writes.add(g),
      );
      expect(await store.setReminderTime(18, 30, now: now), isTrue);
      expect(writes, hasLength(1));
      expect(
        store.scheduleFor('auto')!.nextCheckAt,
        DateTime(2026, 11, 17, 18, 30),
      );
      for (final protected in schedules.skip(1)) {
        expect(store.scheduleFor(protected.plantId), same(protected));
      }
      expect(store.garden.records, isEmpty);
      expect(store.garden.preferences.taskNotifications, isFalse);
      final restored = Garden.fromJson(
        jsonDecode(jsonEncode(store.garden.toJson())) as Map<String, dynamic>,
      );
      final second = GardenStore(garden: restored, persist: (_) async {});
      await second.setReminderTime(7, 15, now: now);
      expect(
        second.scheduleFor('auto')!.nextCheckAt,
        DateTime(2026, 11, 17, 7, 15),
      );
      expect(
        second.scheduleFor('custom-equal')!.nextCheckAt,
        schedules[1].nextCheckAt,
      );
    },
  );

  test(
    'changing preference to an existing task clock keeps that task revision',
    () async {
      final original = schedule(
        'p',
        DateTime(2026, 11, 17, 18, 30),
        CheckTimeSource.preference,
      );
      final store = GardenStore(
        garden: Garden(plants: [plant('p')], schedules: [original]),
        persist: (_) async {},
      );
      await store.setReminderTime(
        18,
        30,
        now: now.add(const Duration(minutes: 1)),
      );
      expect(store.scheduleFor('p'), same(original));
    },
  );

  test(
    'invalid and unchanged times make no writes or syncs; failed save rolls back',
    () async {
      var writes = 0;
      var syncs = 0;
      final store = GardenStore(
        garden: const Garden(),
        persist: (_) async {
          writes++;
          throw StateError('disk full');
        },
        onChanged: (_) async {
          syncs++;
        },
      );
      expect(await store.setReminderTime(9, 0), isTrue);
      expect(await store.setReminderTime(24, 0), isFalse);
      expect(await store.setReminderTime(8, -1), isFalse);
      expect(writes, 0);
      expect(await store.setReminderTime(18, 30), isFalse);
      expect(store.garden.preferences.reminderHour, 9);
      expect(writes, 1);
      expect(syncs, 0);
    },
  );

  test(
    'custom edit survives global changes; completion returns to preferred clock',
    () async {
      final store = GardenStore(garden: const Garden(), persist: (_) async {});
      await store.addPlant(plant('p'), now: now);
      final custom = DateTime(2026, 11, 18, 9);
      await store.editNextCheck('p', custom, now: now);
      expect(store.scheduleFor('p')!.timeSource, CheckTimeSource.custom);
      await store.setReminderTime(18, 30, now: now);
      expect(store.scheduleFor('p')!.nextCheckAt, custom);
      final record = await store.completeWateringCheck(
        plantId: 'p',
        outcome: WateringOutcome.watered,
        soil: Soil.damp,
        now: now,
      );
      expect(record!.recordedAt, now);
      expect(record.scheduledFor, custom);
      expect(
        store.scheduleFor('p')!.nextCheckAt,
        DateTime(2026, 11, 29, 18, 30),
      );
      expect(store.scheduleFor('p')!.timeSource, CheckTimeSource.preference);
      await store.completeWateringCheck(
        plantId: 'p',
        outcome: WateringOutcome.checkedNotWatered,
        soil: Soil.dry,
        now: now,
      );
      expect(
        store.scheduleFor('p')!.nextCheckAt,
        DateTime(2026, 11, 18, 18, 30),
      );
      expect(store.lastWatered('p'), now);
      await store.addPlant(
        plant('new'),
        lastWatered: DateTime(2026, 11, 10, 13),
        now: now,
      );
      expect(
        store.scheduleFor('new')!.nextCheckAt,
        DateTime(2026, 11, 24, 18, 30),
      );
    },
  );

  test(
    'concurrent plant and preference saves cannot overwrite each other',
    () async {
      final pending = Completer<void>();
      var writes = 0;
      final store = GardenStore(
        garden: const Garden(),
        persist: (_) async {
          if (writes++ == 0) await pending.future;
        },
      );
      final first = store.setReminderTime(18, 30, now: now);
      final second = store.addPlant(plant('p'), now: now);
      await Future<void>.delayed(Duration.zero);
      expect(store.garden.plants, isEmpty);
      pending.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(store.garden.preferences.reminderHour, 18);
      expect(
        store.scheduleFor('p')!.nextCheckAt,
        DateTime(2026, 11, 15, 18, 30),
      );
    },
  );

  test(
    'optional notification failure does not undo a committed preference',
    () async {
      final store = GardenStore(
        garden: const Garden(),
        persist: (_) async {},
        onChanged: (_) async {
          throw StateError('Android');
        },
      );
      expect(await store.setReminderTime(18, 30), isTrue);
      expect(store.garden.preferences.reminderHour, 18);
    },
  );

  test(
    'DST missing minute moves to first valid minute; repeated minute fires once',
    () {
      tzdata.initializeTimeZones();
      final berlin = tz.getLocation('Europe/Berlin');
      final gap = reminderOnDay(DateTime(2027, 3, 28), 2, 30, location: berlin);
      expect(gap.hour, 3);
      expect(gap.minute, 0);
      final fold = reminderOnDay(
        DateTime(2027, 10, 31),
        2,
        30,
        location: berlin,
      );
      expect(fold.toUtc(), DateTime.utc(2027, 10, 31, 0, 30));
      expect(
        reminderOnDay(DateTime(2027, 3, 28), 9, 0, location: berlin).hour,
        9,
      );
    },
  );
}
