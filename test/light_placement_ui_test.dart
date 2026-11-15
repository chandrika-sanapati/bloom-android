import 'dart:async';

import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/ui/catalog_screen.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const acknowledgmentLabel = "I've placed it as suggested";

void main() {
  final species = PlantSpecies.catalog[2];
  final plant = Plant(
    id: 'plant-1',
    name: species.name,
    species: species.scientific,
    asset: species.asset,
  );
  final schedule = WateringSchedule(
    plantId: plant.id,
    intervalDays: 14,
    nextCheckAt: DateTime(2026, 12, 1, 9),
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );

  Future<void> openSetup(WidgetTester tester, GardenStore store) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PlantSetupScreen(store: store, species: species),
                ),
              ),
              child: const Text('Open setup'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open setup'));
    await tester.pumpAndSettle();
  }

  Future<void> revealAcknowledgment(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Light & placement'), 200);
    await tester.pumpAndSettle();
    if (find.byType(CheckboxListTile).evaluate().isEmpty) {
      await tester.tap(find.text('Light & placement'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text(acknowledgmentLabel), 150);
    await tester.pumpAndSettle();
  }

  testWidgets('setup can skip optional placement and add immediately', (
    tester,
  ) async {
    final store = GardenStore(garden: const Garden(), persist: (_) async {});
    await openSetup(tester, store);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(store.garden.plants, hasLength(1));
    expect(store.garden.plants.single.lightPlacement, isNull);
    expect(find.text('Open setup'), findsOneWidget);
  });

  testWidgets('setup saves the same suggestion and acknowledgment with Add', (
    tester,
  ) async {
    final snapshots = <Garden>[];
    final store = GardenStore(
      garden: const Garden(),
      persist: (next) async {
        snapshots.add(next);
      },
    );
    await openSetup(tester, store);
    await revealAcknowledgment(tester);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(find.text(species.light.placement), findsOneWidget);
    await tester.tap(find.text(acknowledgmentLabel));
    await tester.pumpAndSettle();
    expect(snapshots, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(snapshots, hasLength(1));
    expect(
      snapshots.single.plants.single.lightPlacement?.guidanceVersion,
      species.light.version,
    );
    expect(snapshots.single.schedules, hasLength(1));
  });

  testWidgets('cancelling setup after checking placement saves nothing', (
    tester,
  ) async {
    var writes = 0;
    final store = GardenStore(
      garden: const Garden(),
      persist: (_) async {
        writes++;
      },
    );
    await openSetup(tester, store);
    await revealAcknowledgment(tester);
    await tester.tap(find.text(acknowledgmentLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(store.garden.plants, isEmpty);
    expect(writes, 0);
  });

  for (final acknowledged in [false, true]) {
    testWidgets(
      'detail starts compact with saved placement=$acknowledged; review writes nothing',
      (tester) async {
        var writes = 0;
        final store = GardenStore(
          garden: Garden(
            plants: [
              acknowledged
                  ? plant.copyWith(
                      lightPlacement: LightPlacementAcknowledgment(
                        acknowledgedAt: DateTime(2026, 11, 15),
                        guidanceVersion: species.light.version,
                      ),
                    )
                  : plant,
            ],
            schedules: [schedule],
          ),
          persist: (_) async {
            writes++;
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PlantDetailScreen(store: store, plantId: plant.id),
          ),
        );
        await tester.scrollUntilVisible(find.text('Light & placement'), 200);
        await tester.pumpAndSettle();
        expect(find.text(species.light.requirement), findsOneWidget);
        expect(
          find.text(
            acknowledged
                ? "You've placed it as suggested"
                : 'Not recorded · Optional',
          ),
          findsOneWidget,
        );
        expect(find.text(species.light.placement), findsNothing);
        expect(find.byType(CheckboxListTile), findsNothing);
        await tester.tap(find.text('Light & placement'));
        await tester.pumpAndSettle();
        expect(find.text(species.light.placement), findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          acknowledged,
        );
        await tester.tap(find.text('Light & placement'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(writes, 0);
        expect(store.scheduleFor(plant.id), same(schedule));
        expect(store.garden.records, isEmpty);
      },
    );
  }

  testWidgets(
    'detail waits for persistence, supports correction, and leaves dates alone',
    (tester) async {
      var pending = Completer<void>();
      var syncs = 0;
      final store = GardenStore(
        garden: Garden(plants: [plant], schedules: [schedule]),
        persist: (_) => pending.future,
        onChanged: (_) async {
          syncs++;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlantDetailScreen(store: store, plantId: plant.id),
        ),
      );
      await revealAcknowledgment(tester);
      expect(find.text(species.light.placement), findsOneWidget);
      await tester.tap(find.text(acknowledgmentLabel));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      pending = Completer<void>()..complete();
      await tester.tap(find.text(acknowledgmentLabel));
      await tester.pumpAndSettle();
      expect(store.plant(plant.id)?.lightPlacement, isNull);
      expect(store.scheduleFor(plant.id), same(schedule));
      expect(syncs, 0);
    },
  );

  testWidgets('detail save failure retains unchecked state and can retry', (
    tester,
  ) async {
    var fail = true;
    final store = GardenStore(
      garden: Garden(plants: [plant], schedules: [schedule]),
      persist: (_) async {
        if (fail) throw StateError('disk full');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlantDetailScreen(store: store, plantId: plant.id),
      ),
    );
    await revealAcknowledgment(tester);
    await tester.tap(find.text(acknowledgmentLabel));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save placement. Try again."), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    fail = false;
    await tester.tap(find.text(acknowledgmentLabel));
    await tester.pumpAndSettle();
    expect(store.plant(plant.id)?.lightPlacement, isNotNull);
  });

  testWidgets(
    'detail restores a saved acknowledgment on a narrow large-text dark screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = GardenStore(
        garden: Garden(
          plants: [
            plant.copyWith(
              lightPlacement: LightPlacementAcknowledgment(
                acknowledgedAt: DateTime(2026, 11, 15),
                guidanceVersion: species.light.version,
              ),
            ),
          ],
          schedules: [schedule],
        ),
        persist: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: PlantDetailScreen(store: store, plantId: plant.id),
        ),
      );
      await revealAcknowledgment(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
