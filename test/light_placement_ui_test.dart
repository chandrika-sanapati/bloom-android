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
    await tester.scrollUntilVisible(
      find.text('Light & placement'),
      200,
      scrollable: _vertical,
    );
    await tester.pumpAndSettle();
    if (find.byType(CheckboxListTile).evaluate().isEmpty) {
      await tester.tap(find.text('Light & placement'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.text(acknowledgmentLabel),
      150,
      scrollable: _vertical,
    );
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

  Future<void> openDetail(
    WidgetTester tester,
    GardenStore store, {
    ThemeData? theme,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PlantDetailScreen(store: store, plantId: plant.id),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: _vertical);
    await tester.pumpAndSettle();
  }

  Plant acknowledgedPlant({int? version}) => plant.copyWith(
    lightPlacement: LightPlacementAcknowledgment(
      acknowledgedAt: DateTime(2026, 11, 15),
      guidanceVersion: version ?? species.light.version,
    ),
  );

  testWidgets(
    'unconfirmed detail opens the guide and asks; review writes nothing',
    (tester) async {
      var writes = 0;
      final store = GardenStore(
        garden: Garden(plants: [plant], schedules: [schedule]),
        persist: (_) async => writes++,
      );
      await openDetail(tester, store);
      await scrollTo(tester, find.text('Is it in a spot like this?'));
      expect(find.text(species.light.placement), findsOneWidget);
      expect(find.text('Yes, it is'), findsOneWidget);
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      expect(find.text('Is it in a spot like this?'), findsNothing);
      expect(find.text(species.light.requirement), findsOneWidget);
      expect(writes, 0);
      expect(store.scheduleFor(plant.id), same(schedule));
    },
  );

  testWidgets('confirmed detail starts collapsed and shows the confirmation', (
    tester,
  ) async {
    final store = GardenStore(
      garden: Garden(plants: [acknowledgedPlant()], schedules: [schedule]),
      persist: (_) async {},
    );
    await openDetail(tester, store);
    await scrollTo(tester, find.text(species.light.requirement));
    expect(
      find.bySemanticsLabel(RegExp('Placement confirmed')),
      findsOneWidget,
    );
    expect(find.text('In a good spot'), findsNothing);
    await tester.tap(find.text(species.light.requirement));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('In a good spot'));
    expect(find.text('Confirmed Nov 15'), findsOneWidget);
    expect(find.text('Is it in a spot like this?'), findsNothing);
  });

  testWidgets('Yes waits for persistence; Change clears it; dates stay put', (
    tester,
  ) async {
    var pending = Completer<void>();
    var syncs = 0;
    final store = GardenStore(
      garden: Garden(plants: [plant], schedules: [schedule]),
      persist: (_) => pending.future,
      onChanged: (_) async => syncs++,
    );
    await openDetail(tester, store);
    await scrollTo(tester, find.text('Yes, it is'));
    await tester.tap(find.text('Yes, it is'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Not yet'),
          )
          .onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('In a good spot'), findsOneWidget);
    expect(store.plant(plant.id)?.lightPlacement, isNotNull);

    pending = Completer<void>()..complete();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(store.plant(plant.id)?.lightPlacement, isNull);
    expect(find.text('Is it in a spot like this?'), findsOneWidget);
    expect(store.scheduleFor(plant.id), same(schedule));
    expect(syncs, 0);
  });

  testWidgets('save failure keeps the question and can retry', (tester) async {
    var fail = true;
    final store = GardenStore(
      garden: Garden(plants: [plant], schedules: [schedule]),
      persist: (_) async {
        if (fail) throw StateError('disk full');
      },
    );
    await openDetail(tester, store);
    await scrollTo(tester, find.text('Yes, it is'));
    await tester.tap(find.text('Yes, it is'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save placement. Try again."), findsOneWidget);
    expect(find.text('Is it in a spot like this?'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Yes, it is'));
    await tester.pumpAndSettle();
    expect(store.plant(plant.id)?.lightPlacement, isNotNull);
  });

  testWidgets('updated advice asks again and records the new version', (
    tester,
  ) async {
    final store = GardenStore(
      garden: Garden(
        plants: [acknowledgedPlant(version: species.light.version - 1)],
        schedules: [schedule],
      ),
      persist: (_) async {},
    );
    await openDetail(tester, store);
    await scrollTo(tester, find.text(species.light.requirement));
    await tester.tap(find.text(species.light.requirement));
    await tester.pumpAndSettle();
    final question = find.text(
      'The advice was updated. Is it still in a spot like this?',
    );
    await scrollTo(tester, question);
    await tester.tap(find.text('Yes, it is'));
    await tester.pumpAndSettle();
    expect(
      store.plant(plant.id)?.lightPlacement?.guidanceVersion,
      species.light.version,
    );
    expect(find.text('In a good spot'), findsOneWidget);
  });

  testWidgets('detail fits a narrow large-text dark screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = GardenStore(
      garden: Garden(plants: [plant], schedules: [schedule]),
      persist: (_) async {},
    );
    await openDetail(
      tester,
      store,
      theme: ThemeData.dark(useMaterial3: true),
      textScale: 2,
    );
    await scrollTo(tester, find.text('Not yet'));
    expect(tester.takeException(), isNull);
  });
}

final _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
