import 'dart:io';
import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/soil_care.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:bloom/ui/plant_timeline_screen.dart';
import 'package:bloom/ui/soil_care_screen.dart';
import 'package:bloom/data/plant_profile_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PlantProfileCatalog.load);
  const native = MethodChannel('bloom.integration/notifications');
  testWidgets(
    'guarded native Back, combined soil care and nested timeline persist safely',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/bloom-timeline-integration.json');
      if (await file.exists()) await file.delete();
      final repository = GardenRepository(file: file);
      final store = GardenStore(
        garden: const Garden(),
        persist: repository.save,
      );
      final species = PlantSpecies.catalog[3];
      final plant = Plant(
        id: 'timeline-plant',
        name: 'Timeline test Pothos',
        species: species.scientific,
        asset: species.asset,
      );
      await store.addPlant(plant);
      await store.completeWateringCheck(
        plantId: plant.id,
        outcome: WateringOutcome.checkedNotWatered,
        soil: Soil.damp,
      );
      final beforeSchedule = store.scheduleFor(plant.id)!.toJson();
      final beforeWatering = store.garden.records.single.toJson();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF007A73),
            useMaterial3: true,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PlantDetailScreen(store: store, plantId: plant.id),
                  ),
                ),
                child: const Text('Open plant'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open plant'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Soil care'),
        180,
        scrollable: _vertical,
      );
      await tester.ensureVisible(find.text('Soil care'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Soil care'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Repotted'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => native.invokeMethod<void>('pressBack'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Repotted'),
            )
            .value,
        isTrue,
      );
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Added nutrients'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Refreshed potting mix'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(SoilCareScreen), findsNothing);
      final reloaded = await repository.load();
      expect(reloaded.soilCare, hasLength(1));
      expect(reloaded.soilCare.single.actions, hasLength(3));
      expect(reloaded.schedules.single.toJson(), beforeSchedule);
      expect(reloaded.records.single.toJson(), beforeWatering);
      await tester.scrollUntilVisible(
        find.text('See all'),
        200,
        scrollable: _vertical,
      );
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.byType(PlantTimelineScreen), findsOneWidget);
      expect(find.text('Checked — not watered'), findsOneWidget);
      expect(find.text(reloaded.soilCare.single.title), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await File(
        '${directory.path}/bloom-care-timeline.png',
      ).writeAsBytes(await binding.takeScreenshot('care-timeline'));
      await tester.tap(find.text(reloaded.soilCare.single.title));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Added nutrients'),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => native.invokeMethod<void>('pressBack'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect((await repository.load()).soilCare.single.actions, hasLength(3));
      await tester.runAsync(() => native.invokeMethod<void>('pressBack'));
      await tester.pumpAndSettle();
      expect(find.byType(PlantDetailScreen), findsOneWidget);
      expect(store.garden.records, hasLength(1));
      await file.delete();
    },
  );

  testWidgets(
    'deletes only the latest watering record and preserves soil care',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/bloom-watering-correction.json');
      if (await file.exists()) await file.delete();
      final repository = GardenRepository(file: file);
      final store = GardenStore(
        garden: const Garden(),
        persist: repository.save,
      );
      final now = DateTime(2026, 11, 15, 10);
      final species = PlantSpecies.catalog[3];
      final plant = Plant(
        id: 'correction-plant',
        name: 'Correction test Pothos',
        species: species.scientific,
        asset: species.asset,
      );
      await store.addPlant(plant, now: now);
      final first = await store.completeWateringCheck(
        plantId: plant.id,
        outcome: WateringOutcome.watered,
        soil: Soil.damp,
        now: DateTime(2026, 11, 16, 14),
      );
      final latest = await store.completeWateringCheck(
        plantId: plant.id,
        outcome: WateringOutcome.watered,
        soil: Soil.damp,
        now: DateTime(2026, 12, 1, 14),
      );
      expect(first, isNotNull);
      expect(latest, isNotNull);
      await store.saveSoilCare(
        SoilCareEvent(
          id: 'correction-soil',
          plantId: plant.id,
          occurredOn: DateTime(2026, 11, 14),
          recordedAt: DateTime(2026, 11, 14, 12),
          actions: {SoilCareAction.mixRefreshed},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorSchemeSeed: const Color(0xFF007A73),
            useMaterial3: true,
          ),
          home: PlantTimelineScreen(store: store, plantId: plant.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Watered'), findsNWidgets(2));
      expect(find.text('Refreshed potting mix'), findsOneWidget);
      // Only the newest watering row is tappable (shows a chevron).
      final wateredRows = find.widgetWithText(ListTile, 'Watered');
      final tappable = [
        for (final element in wateredRows.evaluate())
          if ((element.widget as ListTile).onTap != null) element,
      ];
      expect(tappable, hasLength(1));
      await tester.tap(find.byWidget(tappable.single.widget));
      await tester.pumpAndSettle();
      expect(find.textContaining('Delete this record?'), findsOneWidget);
      await tester.tap(find.text('Delete record'));
      await tester.pumpAndSettle();

      expect(find.text('Watered'), findsOneWidget);
      expect(find.text('Refreshed potting mix'), findsOneWidget);
      expect(store.recordsFor(plant.id), hasLength(1));
      expect(store.recordsFor(plant.id).single.id, first!.id);
      expect(store.lastWatered(plant.id), first.recordedAt);
      expect(
        store.scheduleFor(plant.id)!.nextCheckAt,
        DateTime(2026, 11, 30, 9),
      );
      final reloaded = await repository.load();
      expect(reloaded.records, hasLength(1));
      expect(reloaded.soilCare, hasLength(1));
      expect(reloaded.soilCare.single.id, 'correction-soil');

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(store.recordsFor(plant.id), hasLength(2));
      expect(store.recordsFor(plant.id).first.id, latest!.id);
      expect(store.lastWatered(plant.id), latest.recordedAt);
      expect(
        store.scheduleFor(plant.id)!.nextCheckAt,
        DateTime(2026, 12, 15, 9),
      );
      expect((await repository.load()).records, hasLength(2));
      await file.delete();
    },
  );
}

final _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
