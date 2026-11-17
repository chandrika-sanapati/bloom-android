import 'package:bloom/data/cloud_garden_sync.dart';
import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/data/watering_notifications.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notifications.dart';

void main() {
  final catalog = PlantSpecies.catalog;
  Plant plant(String id, int i) =>
      Plant(id: id, plantTypeId: catalog[i].id, displayName: 'Plant $id');
  WateringSchedule schedule(String id) => WateringSchedule(
    plantId: id,
    intervalDays: 14,
    nextCheckAt: DateTime(2099, 1, 1, 9),
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
    timeSource: CheckTimeSource.preference,
  );
  Garden garden() => Garden(
    plants: [plant('a', 0), plant('b', 1), plant('c', 2)],
    schedules: [schedule('a'), schedule('b'), schedule('c')],
    growthPhotos: [
      GrowthPhoto(
        id: 'ph',
        plantId: 'a',
        takenAt: DateTime.utc(2026, 11, 1),
        path: '/nonexistent/ph.jpg',
      ),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'hasSeenAddPlantHint': true});
  });

  test(
    'deletePlants removes all data for the chosen plants in one save',
    () async {
      var writes = 0;
      final store = GardenStore(
        garden: garden(),
        persist: (_) async => writes++,
      );
      expect(await store.deletePlants({'a', 'missing'}), isFalse);
      expect(writes, 0);
      expect(await store.deletePlants({'a', 'b'}), isTrue);
      expect(writes, 1);
      expect(store.garden.plants.map((p) => p.id), ['c']);
      expect(store.garden.schedules.map((s) => s.plantId), ['c']);
      expect(store.garden.growthPhotos, isEmpty);
    },
  );

  testWidgets('long-press selects plants and deletes them after confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = GardenStore(
      garden: garden().copyWith(growthPhotos: const []),
      persist: (_) async {},
    );
    await tester.pumpWidget(
      BloomApp(
        store: store,
        flags: FirstRunFlags(),
        notifications: WateringNotifications(
          client: FakeNotificationClient(),
          timezone: () async => 'UTC',
        ),
        cloudSync: CloudGardenSync(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Plant a').first);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Plant b').first);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 plants?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.garden.plants, hasLength(3));

    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(store.garden.plants.map((p) => p.id), ['c']);
    expect(find.text('2 plants deleted.'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(find.byTooltip('Profile'), findsOneWidget);
  });

  testWidgets('Select all then Back exits selection without deleting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = GardenStore(
      garden: garden().copyWith(growthPhotos: const []),
      persist: (_) async {},
    );
    await tester.pumpWidget(
      BloomApp(
        store: store,
        flags: FirstRunFlags(),
        notifications: WateringNotifications(
          client: FakeNotificationClient(),
          timezone: () async => 'UTC',
        ),
        cloudSync: CloudGardenSync(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Profile'), findsOneWidget);
    expect(store.garden.plants, hasLength(3));
  });
}
