import 'dart:io';
import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:bloom/ui/plant_timeline_screen.dart';
import 'package:bloom/ui/soil_care_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('bloom.integration/notifications');
  testWidgets(
    'on-demand drainage, guarded native Back, combined soil care and nested timeline persist safely',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/bloom-timeline-integration.json');
      if (await file.exists()) await file.delete();
      final repository = GardenRepository(file: file);
      final store = GardenStore(
        garden: const Garden(),
        persist: repository.save,
      );
      final species = PlantSpecies.catalog.last;
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
      await tester.scrollUntilVisible(find.text('Soil health'), 220);
      await tester.tap(find.text('Soil health'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Refresh potting mix'));
      await tester.tap(find.text('Refresh potting mix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Check drainage first'), findsOneWidget);
      expect(store.garden.soilCare, isEmpty);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Record soil care'), 180);
      await tester.tap(find.text('Record soil care'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repotted'));
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
      await tester.tap(find.text('Added nutrients'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refreshed potting mix'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(SoilCareScreen), findsNothing);
      final reloaded = await repository.load();
      expect(reloaded.soilCare, hasLength(1));
      expect(reloaded.soilCare.single.actions, hasLength(3));
      expect(reloaded.schedules.single.toJson(), beforeSchedule);
      expect(reloaded.records.single.toJson(), beforeWatering);
      await tester.scrollUntilVisible(find.text('Care timeline'), 200);
      await tester.tap(find.text('Care timeline'));
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
      await tester.tap(find.text('Added nutrients'));
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
}
