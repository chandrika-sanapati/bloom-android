import 'dart:io';

import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/ui/catalog_screen.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:bloom/data/plant_profile_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Runs against an isolated cache file, never the user's saved garden.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PlantProfileCatalog.load);
  const label = "I've placed it as suggested";

  Future<void> revealCheckbox(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Light & placement'),
      220,
      scrollable: _vertical,
    );
    await tester.pumpAndSettle();
    if (find.byType(CheckboxListTile).evaluate().isEmpty) {
      await tester.tap(find.text('Light & placement'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      150,
      scrollable: _vertical,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSetup(
    WidgetTester tester,
    GardenStore store,
    PlantSpecies species,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF007A73),
          useMaterial3: true,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PlantSetupScreen(store: store, species: species),
                  ),
                ),
                child: const Text('Add test plant'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add test plant'));
    await tester.pumpAndSettle();
  }

  /// Opens the plant page and makes sure the light panel is expanded.
  Future<void> openDetail(
    WidgetTester tester,
    GardenStore store,
    String plantId,
    PlantSpecies species,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF007A73),
          useMaterial3: true,
        ),
        home: PlantDetailScreen(store: store, plantId: plantId),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.text(species.light.requirement);
    await tester.scrollUntilVisible(row, 220, scrollable: _vertical);
    await tester.pumpAndSettle();
    if (find.text(species.light.placement).evaluate().isEmpty) {
      await tester.tap(row);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.text(species.light.placement),
      150,
      scrollable: _vertical,
    );
    await tester.scrollUntilVisible(
      find.byType(OutlinedButton).last,
      150,
      scrollable: _vertical,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'skip at setup, acknowledge later, reload and correct without watering changes',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/bloom-light-device-test.json');
      if (await file.exists()) await file.delete();
      final repository = GardenRepository(file: file);
      var reminderSyncs = 0;
      final store = GardenStore(
        garden: const Garden(),
        persist: repository.save,
        onChanged: (_) async {
          reminderSyncs++;
        },
      );
      final species = PlantSpecies.catalog[2];
      await openSetup(tester, store, species);
      await revealCheckbox(tester);
      expect(find.text(species.light.placement), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await File(
        '${directory.path}/bloom-light-setup.png',
      ).writeAsBytes(await binding.takeScreenshot('light-placement-setup'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final plant = store.garden.plants.single;
      expect(plant.lightPlacement, isNull);
      final originalSchedule = store.scheduleFor(plant.id)!.toJson();
      reminderSyncs = 0;

      await openDetail(tester, store, plant.id, species);
      expect(find.text('Is it in a spot like this?'), findsOneWidget);
      await tester.tap(find.text('Yes, it is'));
      await tester.pumpAndSettle();
      expect(store.plant(plant.id)?.lightPlacement, isNotNull);
      expect(store.scheduleFor(plant.id)!.toJson(), originalSchedule);
      expect(reminderSyncs, 0);

      final reloaded = GardenStore(
        garden: await repository.load(),
        persist: repository.save,
      );
      await openDetail(tester, reloaded, plant.id, species);
      expect(find.text('In a good spot'), findsOneWidget);
      await File(
        '${directory.path}/bloom-light-detail.png',
      ).writeAsBytes(await binding.takeScreenshot('light-placement-detail'));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect((await repository.load()).plants.single.lightPlacement, isNull);
      expect(reloaded.scheduleFor(plant.id)!.toJson(), originalSchedule);
      expect(reloaded.garden.records, isEmpty);
      await file.delete();
    },
  );

  testWidgets('acknowledgment during setup is saved and restored on detail', (
    tester,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/bloom-light-setup-device-test.json');
    if (await file.exists()) await file.delete();
    final repository = GardenRepository(file: file);
    final store = GardenStore(garden: const Garden(), persist: repository.save);
    final species = PlantSpecies.catalog[3];
    await openSetup(tester, store, species);
    await revealCheckbox(tester);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(await file.exists(), isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    final restored = GardenStore(
      garden: await repository.load(),
      persist: repository.save,
    );
    final plant = restored.garden.plants.single;
    expect(plant.lightPlacement?.guidanceVersion, species.light.version);
    expect(restored.garden.schedules, hasLength(1));
    await openDetail(tester, restored, plant.id, species);
    expect(find.text('In a good spot'), findsOneWidget);
    expect(find.text(species.light.placement), findsOneWidget);
    await file.delete();
  });
}

final _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
