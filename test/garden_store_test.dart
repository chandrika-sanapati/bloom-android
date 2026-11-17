import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/soil_care.dart';

void main() {
  final now = DateTime(2026, 11, 15, 10);

  Plant plant({String name = 'Pothos', String? species}) => Plant(
    id: 'plant-1',
    name: name,
    species: species ?? 'Epipremnum aureum',
    asset: 'assets/images/pothos.jpg',
  );

  GardenStore storeWith({Future<void> Function(Garden)? persist}) =>
      GardenStore(garden: const Garden(), persist: persist ?? (_) async {});

  Future<GardenStore> storeWithPlant({
    Future<void> Function(Garden)? persist,
    DateTime? lastWatered,
  }) async {
    final store = storeWith(persist: persist);
    final added = await store.addPlant(
      plant(),
      lastWatered: lastWatered,
      now: now,
    );
    expect(added, isTrue);
    return store;
  }

  group('watering profiles and first checks', () {
    test(
      'normalizes photo/provider Pothos variants to the reviewed profile',
      () async {
        final store = storeWith();
        final added = await store.addPlant(
          Plant(
            id: 'photo-pothos',
            name: 'Golden Pothos',
            species: 'Epipremnum aureum njoy',
            asset: 'assets/images/area-whole.png',
          ),
          now: now,
        );

        expect(added, isTrue);
        final saved = store.plant('photo-pothos');
        expect(saved?.name, 'Pothos');
        expect(saved?.species, 'Epipremnum aureum');
        expect(saved?.asset, 'assets/images/pothos.jpg');
        expect(store.scheduleFor('photo-pothos')?.intervalDays, 14);
      },
    );

    test('canonicalizes legacy catalog variants on store load', () {
      final store = GardenStore(
        garden: Garden(
          plants: [
            Plant(
              id: 'legacy-pothos',
              name: 'Devil’s Ivy',
              species: 'unknown provider species',
              asset: 'assets/images/area-whole.png',
            ),
          ],
        ),
        persist: (_) async {},
      );

      expect(store.plant('legacy-pothos')?.name, 'Pothos');
      expect(store.plant('legacy-pothos')?.species, 'Epipremnum aureum');
      expect(store.plant('legacy-pothos')?.asset, 'assets/images/pothos.jpg');
      expect(store.scheduleFor('legacy-pothos'), isNull);
    });

    test('creates a Pothos schedule from a known last-watered date', () async {
      final store = await storeWithPlant(lastWatered: DateTime(2026, 11, 1));

      expect(store.scheduleFor('plant-1')?.intervalDays, 14);
      expect(
        store.scheduleFor('plant-1')?.nextCheckAt,
        DateTime(2026, 11, 15, 9),
      );
    });

    test('creates a same-day baseline when last-watered is unknown', () async {
      final store = await storeWithPlant();

      expect(
        store.scheduleFor('plant-1')?.nextCheckAt,
        DateTime(2026, 11, 15, 9),
      );
    });

    test('rejects a future last-watered date at the domain boundary', () async {
      final store = storeWith();

      final added = await store.addPlant(
        plant(),
        lastWatered: now.add(const Duration(minutes: 1)),
        now: now,
      );

      expect(added, isFalse);
      expect(store.garden.plants, isEmpty);
    });

    test('stores an unsupported plant without inventing a schedule', () async {
      final store = storeWith();

      final added = await store.addPlant(
        plant(name: 'Unknown plant', species: 'Unknown species'),
        now: now,
      );

      expect(added, isTrue);
      expect(store.garden.plants, hasLength(1));
      expect(store.garden.schedules, isEmpty);
    });

    test('creates the reviewed Spider Plant profile', () async {
      final store = storeWith();
      final spider = Plant(
        id: 'spider-1',
        name: 'Spider Plant',
        species: 'Chlorophytum comosum',
        asset: 'assets/images/spider.jpg',
      );

      expect(await store.addPlant(spider, now: now), isTrue);
      expect(store.scheduleFor('spider-1')?.intervalDays, 10);
      expect(
        store.scheduleFor('spider-1')?.nextCheckAt,
        DateTime(2026, 11, 15, 9),
      );
      expect(PlantSpecies.forPlant(spider)?.minDays, 7);
      expect(PlantSpecies.forPlant(spider)?.maxDays, 14);
    });
  });

  group('schedule timing', () {
    test('classifies dates as overdue, today, or upcoming', () {
      expect(
        CareTaskTiming.classify(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        CareTaskTiming.overdue,
      );
      expect(
        CareTaskTiming.classify(DateTime(2026, 11, 15, 23), now: now),
        CareTaskTiming.today,
      );
      expect(
        CareTaskTiming.classify(now.add(const Duration(days: 1)), now: now),
        CareTaskTiming.upcoming,
      );
    });

    test(
      'watered updates Last watered and uses the profile interval',
      () async {
        final store = await storeWithPlant();
        final recordedAt = DateTime(2026, 11, 16, 14);

        final record = await store.completeWateringCheck(
          plantId: 'plant-1',
          outcome: WateringOutcome.watered,
          soil: Soil.damp,
          now: recordedAt,
        );

        expect(record?.outcome, WateringOutcome.watered);
        expect(store.lastWatered('plant-1'), recordedAt);
        expect(
          store.scheduleFor('plant-1')?.nextCheckAt,
          DateTime(2026, 11, 30, 9),
        );
        expect(record?.scheduledFor, DateTime(2026, 11, 15, 9));
      },
    );

    test('a dry non-watering check uses the three-day follow-up', () async {
      final store = await storeWithPlant(lastWatered: DateTime(2026, 11, 1));
      final recordedAt = DateTime(2026, 11, 16, 14);

      final record = await store.completeWateringCheck(
        plantId: 'plant-1',
        outcome: WateringOutcome.checkedNotWatered,
        soil: Soil.dry,
        now: recordedAt,
      );

      expect(record?.outcome, WateringOutcome.checkedNotWatered);
      expect(store.lastWatered('plant-1'), isNull);
      expect(
        store.scheduleFor('plant-1')?.nextCheckAt,
        DateTime(2026, 11, 19, 9),
      );
    });

    test(
      'a damp non-watering check uses the normal profile interval',
      () async {
        final store = await storeWithPlant();
        final recordedAt = DateTime(2026, 11, 16, 14);

        await store.completeWateringCheck(
          plantId: 'plant-1',
          outcome: WateringOutcome.checkedNotWatered,
          soil: Soil.damp,
          now: recordedAt,
        );

        expect(
          store.scheduleFor('plant-1')?.nextCheckAt,
          DateTime(2026, 11, 30, 9),
        );
        expect(store.lastWatered('plant-1'), isNull);
      },
    );

    test('edits a future next check without creating a record', () async {
      final store = await storeWithPlant();
      final edited = DateTime(2026, 12, 1, 8, 30);

      final saved = await store.editNextCheck('plant-1', edited, now: now);

      expect(saved, isTrue);
      expect(store.scheduleFor('plant-1')?.nextCheckAt, edited);
      expect(store.garden.records, isEmpty);
    });

    test('rejects a past next check without changing the schedule', () async {
      final store = await storeWithPlant();
      final original = store.scheduleFor('plant-1')!.nextCheckAt;

      final saved = await store.editNextCheck(
        'plant-1',
        now.subtract(const Duration(minutes: 1)),
        now: now,
      );

      expect(saved, isFalse);
      expect(store.scheduleFor('plant-1')?.nextCheckAt, original);
    });

    test(
      'deletes only the latest watering record and recalculates state',
      () async {
        final store = await storeWithPlant();
        final first = await store.completeWateringCheck(
          plantId: 'plant-1',
          outcome: WateringOutcome.watered,
          soil: Soil.damp,
          now: DateTime(2026, 11, 16, 14),
        );
        final second = await store.completeWateringCheck(
          plantId: 'plant-1',
          outcome: WateringOutcome.checkedNotWatered,
          soil: Soil.dry,
          now: DateTime(2026, 11, 20, 14),
        );

        expect(first, isNotNull);
        expect(second, isNotNull);
        final deleted = await store.deleteLatestWateringRecord(
          'plant-1',
          second!.id,
          now: DateTime(2026, 11, 21, 10),
        );

        expect(deleted, isTrue);
        expect(store.recordsFor('plant-1'), hasLength(1));
        expect(store.recordsFor('plant-1').single.id, first!.id);
        expect(store.lastWatered('plant-1'), first.recordedAt);
        expect(
          store.scheduleFor('plant-1')?.nextCheckAt,
          DateTime(2026, 11, 30, 9),
        );
      },
    );

    test('refuses to delete an older watering record', () async {
      final store = await storeWithPlant();
      final first = await store.completeWateringCheck(
        plantId: 'plant-1',
        outcome: WateringOutcome.watered,
        soil: Soil.damp,
        now: DateTime(2026, 11, 16, 14),
      );
      await store.completeWateringCheck(
        plantId: 'plant-1',
        outcome: WateringOutcome.watered,
        soil: Soil.damp,
        now: DateTime(2026, 11, 20, 14),
      );
      final before = store.garden.toJson();

      final deleted = await store.deleteLatestWateringRecord(
        'plant-1',
        first!.id,
      );

      expect(deleted, isFalse);
      expect(store.garden.toJson(), before);
    });

    test(
      'failed watering-record deletion leaves the garden unchanged',
      () async {
        var shouldFail = false;
        final store = await storeWithPlant(
          persist: (_) async {
            if (shouldFail) throw StateError('disk full');
          },
        );
        final record = await store.completeWateringCheck(
          plantId: 'plant-1',
          outcome: WateringOutcome.watered,
          soil: Soil.damp,
          now: DateTime(2026, 11, 16, 14),
        );
        final before = store.garden.toJson();
        shouldFail = true;

        final deleted = await store.deleteLatestWateringRecord(
          'plant-1',
          record!.id,
        );

        expect(deleted, isFalse);
        expect(store.garden.toJson(), before);
      },
    );

    test(
      'watering-record correction preserves a later custom next check',
      () async {
        final store = await storeWithPlant();
        final record = await store.completeWateringCheck(
          plantId: 'plant-1',
          outcome: WateringOutcome.watered,
          soil: Soil.damp,
          now: DateTime(2026, 11, 16, 14),
        );
        final custom = DateTime(2026, 12, 15, 16, 30);
        await store.editNextCheck(
          'plant-1',
          custom,
          now: DateTime(2026, 11, 17),
        );

        final deleted = await store.deleteLatestWateringRecord(
          'plant-1',
          record!.id,
          now: DateTime(2026, 11, 18),
        );

        expect(deleted, isTrue);
        expect(store.garden.records, isEmpty);
        expect(store.scheduleFor('plant-1')?.nextCheckAt, custom);
        expect(
          store.scheduleFor('plant-1')?.timeSource,
          CheckTimeSource.custom,
        );
      },
    );
  });

  test(
    'undoes the latest watering correction while the garden is unchanged',
    () async {
      final store = await storeWithPlant();
      final record = await store.completeWateringCheck(
        plantId: 'plant-1',
        outcome: WateringOutcome.watered,
        soil: Soil.damp,
        now: DateTime(2026, 11, 16, 14),
      );
      final before = store.scheduleFor('plant-1')!.toJson();
      expect(
        await store.deleteLatestWateringRecord('plant-1', record!.id),
        isTrue,
      );

      expect(await store.undoLatestWateringCorrection(), isTrue);
      expect(store.garden.records, hasLength(1));
      expect(store.garden.records.single.id, record.id);
      expect(store.scheduleFor('plant-1')?.toJson(), before);
    },
  );

  test('undo is invalidated by a later saved change', () async {
    final store = await storeWithPlant();
    final record = await store.completeWateringCheck(
      plantId: 'plant-1',
      outcome: WateringOutcome.watered,
      soil: Soil.damp,
      now: DateTime(2026, 11, 16, 14),
    );
    expect(
      await store.deleteLatestWateringRecord('plant-1', record!.id),
      isTrue,
    );
    expect(
      await store.editNextCheck(
        'plant-1',
        DateTime(2026, 12, 15, 9),
        now: DateTime(2026, 11, 17),
      ),
      isTrue,
    );

    expect(await store.undoLatestWateringCorrection(), isFalse);
    expect(store.garden.records, isEmpty);
  });

  group('persistence boundary', () {
    test(
      'local save does not wait for a failing asynchronous callback',
      () async {
        final callbackStarted = Completer<void>();
        final callbackRelease = Completer<void>();
        final store = GardenStore(
          garden: const Garden(),
          persist: (_) async {},
          onPersisted: (_) async {
            callbackStarted.complete();
            await callbackRelease.future;
            throw StateError('cloud unavailable');
          },
        );

        expect(await store.addPlant(plant(), now: now), isTrue);
        expect(store.garden.plants, hasLength(1));
        await callbackStarted.future;
        callbackRelease.complete();
        await Future<void>.delayed(Duration.zero);
        expect(store.garden.plants, hasLength(1));
      },
    );

    test(
      'every local save queues persistence callback, including side-effect-free saves',
      () async {
        var callbacks = 0;
        final store = GardenStore(
          garden: const Garden(),
          persist: (_) async {},
          onPersisted: (_) async => callbacks++,
        );

        expect(
          await store.saveSoilCare(
            SoilCareEvent(
              id: 'event-1',
              plantId: 'missing',
              occurredOn: now,
              recordedAt: now,
              actions: {SoilCareAction.mixRefreshed},
            ),
          ),
          isFalse,
        );
        expect(callbacks, 0);

        await store.addPlant(plant(), now: now);
        await Future<void>.delayed(Duration.zero);
        expect(callbacks, 1);
      },
    );

    test('failed saves leave the garden unchanged', () async {
      var attempts = 0;
      final store = storeWith(
        persist: (_) async {
          attempts += 1;
          throw StateError('disk full');
        },
      );

      final added = await store.addPlant(plant(), now: now);

      expect(added, isFalse);
      expect(attempts, 1);
      expect(store.garden.plants, isEmpty);
      expect(store.garden.schedules, isEmpty);
      expect(store.garden.records, isEmpty);
    });

    test(
      'failed completion does not add a record or move the schedule',
      () async {
        var shouldFail = false;
        final store = await storeWithPlant(
          persist: (_) async {
            if (shouldFail) throw StateError('disk full');
          },
        );
        final original = store.scheduleFor('plant-1')!.nextCheckAt;
        shouldFail = true;

        final record = await store.completeWateringCheck(
          plantId: 'plant-1',
          outcome: WateringOutcome.watered,
          soil: Soil.damp,
          now: now.add(const Duration(days: 1)),
        );

        expect(record, isNull);
        expect(store.garden.records, isEmpty);
        expect(store.scheduleFor('plant-1')?.nextCheckAt, original);
      },
    );
  });
}
