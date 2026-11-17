import 'dart:convert';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/soil_care.dart';
import 'package:bloom/domain/plant_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 15, 14);
  final species = PlantSpecies.catalog[3];
  Plant plant(String id) => Plant(
    id: id,
    name: id,
    species: species.scientific,
    asset: species.asset,
  );
  SoilCareEvent event(
    String id,
    Set<SoilCareAction> actions, {
    String plantId = 'p',
  }) => SoilCareEvent(
    id: id,
    plantId: plantId,
    occurredOn: DateTime(2026, 11, 14),
    recordedAt: now,
    actions: actions,
  );

  test(
    'old JSON and invalid optional soil entry preserve the existing garden',
    () {
      final json = Garden(plants: [plant('p')]).toJson()..remove('soilCare');
      expect(Garden.fromJson(json).soilCare, isEmpty);
      final loaded = Garden.fromJson({
        ...json,
        'soilCare': [
          {'bad': true},
        ],
      });
      expect(loaded.plants.single.id, 'p');
      expect(loaded.soilCare, isEmpty);
    },
  );
  test('all seven combinations round-trip as single independent events', () {
    for (var mask = 1; mask < 8; mask++) {
      final actions = {
        for (var i = 0; i < 3; i++)
          if ((mask & (1 << i)) != 0) SoilCareAction.values[i],
      };
      final record = event('$mask', actions);
      final loaded = SoilCareEvent.tryFromJson(
        jsonDecode(jsonEncode(record.toJson())),
      )!;
      expect(loaded.actions, actions);
      expect(loaded.occurredOn, record.occurredOn);
    }
    final invalid = event('x', {SoilCareAction.repotted}).toJson()
      ..['occurredOn'] = '2026-02-31';
    expect(SoilCareEvent.tryFromJson(invalid), isNull);
  });
  test(
    'soil saves and corrections never alter watering, placement, preference or notifications',
    () async {
      final placement = LightPlacementAcknowledgment(
        acknowledgedAt: now,
        guidanceVersion: 1,
      );
      var syncs = 0;
      final store = GardenStore(
        garden: Garden(
          plants: [plant('p').copyWith(lightPlacement: placement)],
        ),
        persist: (_) async {},
        onChanged: (_) async {
          syncs++;
        },
      );
      await store.addPlant(plant('q'), now: now);
      syncs = 0;
      final schedules = store.garden.schedules;
      expect(
        await store.saveSoilCare(
          event('job', SoilCareAction.values.toSet()),
          now: now,
        ),
        isTrue,
      );
      expect(store.soilCareFor('p'), hasLength(1));
      expect(store.garden.schedules, same(schedules));
      expect(store.garden.records, isEmpty);
      expect(store.plant('p')!.lightPlacement, same(placement));
      expect(syncs, 0);
      expect(
        await store.saveSoilCare(
          event('job', {SoilCareAction.mixRefreshed}),
          updating: true,
          now: now,
        ),
        isTrue,
      );
      expect(store.soilCareFor('p').single.actions, {
        SoilCareAction.mixRefreshed,
      });
      expect(await store.removeSoilCare('p', 'job'), isTrue);
      expect(store.garden.soilCare, isEmpty);
      expect(syncs, 0);
      expect(
        await store.saveSoilCare(
          event('job', {SoilCareAction.repotted}),
          updating: true,
          now: now,
        ),
        isFalse,
      );
    },
  );
  test(
    'validation, failed save, and plant deletion protect existing data',
    () async {
      var fail = false;
      final store = GardenStore(
        garden: Garden(plants: [plant('p')]),
        persist: (_) async {
          if (fail) throw StateError('disk');
        },
      );
      expect(await store.saveSoilCare(event('x', {}), now: now), isFalse);
      expect(
        await store.saveSoilCare(
          event('x', {SoilCareAction.repotted}, plantId: 'missing'),
          now: now,
        ),
        isFalse,
      );
      fail = true;
      expect(
        await store.saveSoilCare(
          event('x', {SoilCareAction.repotted}),
          now: now,
        ),
        isFalse,
      );
      expect(store.garden.soilCare, isEmpty);
      fail = false;
      await store.saveSoilCare(event('x', {SoilCareAction.repotted}), now: now);
      await store.deletePlant('p');
      expect(store.garden.soilCare, isEmpty);
    },
  );
  test(
    'future dates and cross-plant edits are rejected; recorded timestamp stays UTC',
    () async {
      final store = GardenStore(
        garden: Garden(plants: [plant('p'), plant('q')]),
        persist: (_) async {},
      );
      final future = SoilCareEvent(
        id: 'future',
        plantId: 'p',
        occurredOn: now.add(const Duration(days: 1)),
        recordedAt: now,
        actions: {SoilCareAction.repotted},
      );
      expect(await store.saveSoilCare(future, now: now), isFalse);
      final first = event('job', {SoilCareAction.repotted});
      await store.saveSoilCare(first, now: now);
      expect(
        await store.saveSoilCare(
          event('job', {SoilCareAction.mixRefreshed}, plantId: 'q'),
          updating: true,
          now: now,
        ),
        isFalse,
      );
      expect(first.toJson()['recordedAt'], endsWith('Z'));
      expect(
        () => first.actions.add(SoilCareAction.nutrientsAdded),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'timeline filters one plant, combines soil actions once and uses completed time, not due time',
    () {
      final record = WateringRecord(
        id: 'w',
        plantId: 'p',
        scheduledFor: now.subtract(const Duration(days: 10)),
        recordedAt: now,
        outcome: WateringOutcome.checkedNotWatered,
        soil: Soil.dry,
      );
      final garden = Garden(
        plants: [
          plant('p').copyWith(
            lightPlacement: LightPlacementAcknowledgment(
              acknowledgedAt: now.add(const Duration(hours: 1)),
              guidanceVersion: 1,
            ),
          ),
          plant('q'),
        ],
        records: [record],
        soilCare: [
          event('job', SoilCareAction.values.toSet()),
          event('other', {SoilCareAction.repotted}, plantId: 'q'),
        ],
      );
      final timeline = PlantActivity.forPlant(garden, 'p');
      expect(timeline, hasLength(3));
      expect(timeline.first.kind, PlantActivityKind.placement);
      expect(timeline[1].date, now);
      expect(timeline[1].kind, PlantActivityKind.checked);
      expect(timeline.last.soilCare!.actions, hasLength(3));
      expect(PlantActivity.forPlant(garden, 'missing'), isEmpty);
    },
  );
  test('garden-wide activity includes repotting for every plant', () {
    final garden = Garden(
      plants: [plant('p'), plant('q')],
      soilCare: [
        event('r', {SoilCareAction.repotted}),
        event('n', {SoilCareAction.nutrientsAdded}, plantId: 'q'),
      ],
    );
    final activity = PlantActivity.forGarden(garden);
    expect(activity.map((a) => a.plantId).toSet(), {'p', 'q'});
    expect(
      activity.any(
        (a) =>
            a.plantId == 'p' &&
            a.soilCare!.actions.contains(SoilCareAction.repotted),
      ),
      isTrue,
    );
  });
}
