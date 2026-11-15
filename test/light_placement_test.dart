import 'dart:convert';
import 'dart:io';

import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 15, 10);
  final species = PlantSpecies.catalog[3];
  final plant = Plant(
    id: 'plant-1',
    name: species.name,
    species: species.scientific,
    asset: species.asset,
  );
  final acknowledgment = LightPlacementAcknowledgment(
    acknowledgedAt: now,
    guidanceVersion: species.light.version,
  );

  Garden populatedGarden({LightPlacementAcknowledgment? placement}) => Garden(
    plants: [
      plant.copyWith(lightPlacement: placement),
      Plant(
        id: 'plant-2',
        name: 'Second Pothos',
        species: plant.species,
        asset: plant.asset,
      ),
    ],
    schedules: [
      WateringSchedule(
        plantId: plant.id,
        intervalDays: 14,
        nextCheckAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ],
    records: [
      WateringRecord(
        id: 'record-1',
        plantId: plant.id,
        scheduledFor: now.subtract(const Duration(days: 16)),
        recordedAt: now.subtract(const Duration(days: 15)),
        outcome: WateringOutcome.watered,
        soil: Soil.dry,
      ),
    ],
    preferences: const AppPreferences(taskNotifications: true),
  );

  test('old garden JSON loads without a placement acknowledgment', () {
    final json = populatedGarden().toJson();
    final restored = Garden.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    expect(restored.plants.first.lightPlacement, isNull);
    expect(restored.toJson(), json);
  });

  test('invalid optional placement data does not discard a valid plant', () {
    for (final invalid in [
      'invalid',
      <String, dynamic>{'acknowledgedAt': 'not-a-date', 'guidanceVersion': 1},
      <String, dynamic>{'acknowledgedAt': now.toIso8601String()},
    ]) {
      final json = plant.toJson()..['lightPlacement'] = invalid;
      final restored = Plant.fromJson(json);
      expect(restored.id, plant.id);
      expect(restored.lightPlacement, isNull);
    }
  });

  test(
    'acknowledgment survives repository save/reload and can be cleared',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bloom-placement-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = GardenRepository(
        file: File('${directory.path}/garden.json'),
      );
      final store = GardenStore(
        garden: populatedGarden(),
        persist: repository.save,
      );
      expect(
        await store.setLightPlacementAcknowledged(plant.id, true, now: now),
        isTrue,
      );
      final reloaded = await repository.load();
      expect(reloaded.plants.first.lightPlacement?.acknowledgedAt, now);
      expect(
        reloaded.plants.first.lightPlacement?.guidanceVersion,
        species.light.version,
      );
      final relaunched = GardenStore(
        garden: reloaded,
        persist: repository.save,
      );
      expect(
        await relaunched.setLightPlacementAcknowledged(plant.id, false),
        isTrue,
      );
      expect((await repository.load()).plants.first.lightPlacement, isNull);
    },
  );

  test('plant copy preserves acknowledgment unless explicitly cleared', () {
    final acknowledged = plant.copyWith(lightPlacement: acknowledgment);
    expect(
      acknowledged.copyWith(name: 'My Pothos').lightPlacement,
      same(acknowledgment),
    );
    expect(
      acknowledged.copyWith(clearLightPlacement: true).lightPlacement,
      isNull,
    );
  });

  for (final lastWatered in <DateTime?>[null, DateTime(2026, 11, 1)]) {
    test(
      'setup acknowledgment preserves first-check calculation ($lastWatered)',
      () async {
        final snapshots = <Garden>[];
        final control = GardenStore(
          garden: const Garden(),
          persist: (_) async {},
        );
        final store = GardenStore(
          garden: const Garden(),
          persist: (next) async {
            snapshots.add(next);
          },
        );
        await control.addPlant(plant, lastWatered: lastWatered, now: now);
        expect(
          await store.addPlant(
            plant.copyWith(lightPlacement: acknowledgment),
            lastWatered: lastWatered,
            now: now,
          ),
          isTrue,
        );
        expect(snapshots, hasLength(1));
        expect(
          snapshots.single.plants.single.lightPlacement,
          same(acknowledgment),
        );
        expect(
          store.scheduleFor(plant.id)?.toJson(),
          control.scheduleFor(plant.id)?.toJson(),
        );
      },
    );
  }

  test(
    'acknowledging and clearing preserve all other data and never sync reminders',
    () async {
      final initial = populatedGarden();
      var reminderSyncs = 0;
      final saved = <Garden>[];
      final store = GardenStore(
        garden: initial,
        persist: (next) async {
          saved.add(next);
        },
        onChanged: (_) async {
          reminderSyncs++;
        },
      );
      expect(
        await store.setLightPlacementAcknowledged(plant.id, true, now: now),
        isTrue,
      );
      final actual = store.garden.toJson();
      ((actual['plants'] as List).first as Map).remove('lightPlacement');
      expect(actual, initial.toJson());
      expect(
        store.lastWatered(plant.id),
        now.subtract(const Duration(days: 15)),
      );
      expect(store.garden.plants.last, same(initial.plants.last));
      expect(
        await store.setLightPlacementAcknowledged(plant.id, false),
        isTrue,
      );
      expect(store.garden.toJson(), initial.toJson());
      expect(saved, hasLength(2));
      expect(reminderSyncs, 0);
    },
  );

  test(
    'repeated confirmations preserve timestamp/version and do not write again',
    () async {
      var writes = 0;
      final store = GardenStore(
        garden: populatedGarden(),
        persist: (_) async {
          writes++;
        },
      );
      await store.setLightPlacementAcknowledged(plant.id, true, now: now);
      await store.setLightPlacementAcknowledged(
        plant.id,
        true,
        now: now.add(const Duration(days: 1)),
      );
      expect(store.plant(plant.id)?.lightPlacement?.acknowledgedAt, now);
      expect(writes, 1);
      await store.setLightPlacementAcknowledged(plant.id, false);
      await store.setLightPlacementAcknowledged(plant.id, false);
      expect(writes, 2);
    },
  );

  test(
    'old guidance version remains recorded until explicit correction',
    () async {
      final earlier = LightPlacementAcknowledgment(
        acknowledgedAt: now,
        guidanceVersion: 99,
      );
      var writes = 0;
      final store = GardenStore(
        garden: populatedGarden(placement: earlier),
        persist: (_) async {
          writes++;
        },
      );
      await store.setLightPlacementAcknowledged(plant.id, true);
      expect(store.plant(plant.id)?.lightPlacement, same(earlier));
      expect(writes, 0);
      await store.setLightPlacementAcknowledged(plant.id, false);
      await store.setLightPlacementAcknowledged(plant.id, true, now: now);
      expect(
        store.plant(plant.id)?.lightPlacement?.guidanceVersion,
        species.light.version,
      );
    },
  );

  test(
    'failed confirmation or correction preserves the saved garden and allows retry',
    () async {
      var fail = true;
      var syncs = 0;
      final store = GardenStore(
        garden: populatedGarden(),
        persist: (_) async {
          if (fail) throw StateError('disk full');
        },
        onChanged: (_) async {
          syncs++;
        },
      );
      final original = store.garden.toJson();
      expect(
        await store.setLightPlacementAcknowledged(plant.id, true),
        isFalse,
      );
      expect(store.garden.toJson(), original);
      fail = false;
      expect(
        await store.setLightPlacementAcknowledged(plant.id, true, now: now),
        isTrue,
      );
      final committed = store.garden.toJson();
      fail = true;
      expect(
        await store.setLightPlacementAcknowledged(plant.id, false),
        isFalse,
      );
      expect(store.garden.toJson(), committed);
      expect(syncs, 0);
    },
  );

  test(
    'failed setup writes neither plant nor its acknowledgment/schedule',
    () async {
      final store = GardenStore(
        garden: const Garden(),
        persist: (_) async {
          throw StateError('disk full');
        },
      );
      expect(
        await store.addPlant(plant.copyWith(lightPlacement: acknowledgment)),
        isFalse,
      );
      expect(store.garden.plants, isEmpty);
      expect(store.garden.schedules, isEmpty);
    },
  );

  test(
    'missing or unsupported plant cannot create an acknowledgment',
    () async {
      var writes = 0;
      final store = GardenStore(
        garden: const Garden(
          plants: [
            Plant(id: 'unknown', name: 'Unknown', species: '', asset: ''),
          ],
        ),
        persist: (_) async {
          writes++;
        },
      );
      expect(
        await store.setLightPlacementAcknowledged('missing', true),
        isFalse,
      );
      expect(
        await store.setLightPlacementAcknowledged('unknown', true),
        isFalse,
      );
      expect(writes, 0);
    },
  );
}
