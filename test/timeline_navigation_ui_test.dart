import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/soil_care.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:bloom/ui/plant_timeline_screen.dart';
import 'package:bloom/ui/soil_care_screen.dart';
import 'package:bloom/ui/check_screen.dart';
import 'package:bloom/ui/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final species = PlantSpecies.catalog[3];
  final plant = Plant(
    id: 'p',
    name: 'Window Pothos',
    species: species.scientific,
    asset: species.asset,
  );
  final now = DateTime.now();
  final schedule = WateringSchedule(
    plantId: 'p',
    intervalDays: 14,
    nextCheckAt: now,
    createdAt: now,
    updatedAt: now,
  );
  GardenStore makeStore({
    Future<void> Function(Garden)? persist,
    List<SoilCareEvent> events = const [],
  }) => GardenStore(
    garden: Garden(plants: [plant], schedules: [schedule], soilCare: events),
    persist: persist ?? (_) async {},
  );
  Future<void> open(
    WidgetTester tester,
    Widget page, {
    bool large = false,
  }) async {
    if (large) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: large ? ThemeData.dark(useMaterial3: true) : null,
        builder: (context, child) => large
            ? MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: child!,
              )
            : child!,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('Open plant'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open plant'));
    await tester.pumpAndSettle();
  }

  Future<void> soilAction(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'plant detail shows history inline and See all opens the full timeline',
    (tester) async {
      final store = makeStore();
      await open(tester, PlantDetailScreen(store: store, plantId: 'p'));
      await tester.scrollUntilVisible(
        find.text('Checks, care and photos will appear here.'),
        250,
        scrollable: _vertical,
      );
      expect(find.text('See all'), findsNothing);
      await store.completeWateringCheck(
        plantId: 'p',
        outcome: WateringOutcome.checkedNotWatered,
        soil: Soil.damp,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('See all'),
        250,
        scrollable: _vertical,
      );
      expect(find.text('Checked — not watered'), findsOneWidget);
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.byType(PlantTimelineScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PlantDetailScreen), findsOneWidget);
    },
  );
  testWidgets(
    'dirty watering form protects toolbar and system Back; Keep editing preserves choices',
    (tester) async {
      final store = makeStore();
      await open(tester, CheckScreen(store: store, plantId: 'p'));
      await tester.tap(find.text('Checked — not watered'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckScreen), findsNothing);
      expect(store.garden.records, isEmpty);
    },
  );
  testWidgets(
    'watering check only shows soil choices after not watering is selected',
    (tester) async {
      final store = makeStore();
      await open(tester, CheckScreen(store: store, plantId: 'p'));

      expect(find.text('What did you find?'), findsNothing);
      await tester.tap(find.text('Checked — not watered'));
      await tester.pump();
      expect(find.text('What did you find?'), findsOneWidget);
    },
  );

  testWidgets(
    'clean form returns immediately and successful save exits without discard prompt',
    (tester) async {
      final store = makeStore();
      await open(tester, CheckScreen(store: store, plantId: 'p'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      await tester.tap(find.text('Open plant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watered'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckScreen), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
      expect(store.garden.records, hasLength(1));
    },
  );
  testWidgets(
    'setup Back preserves placement when kept and discards only after confirmation',
    (tester) async {
      final store = GardenStore(garden: const Garden(), persist: (_) async {});
      await open(tester, PlantSetupScreen(store: store, species: species));
      await tester.scrollUntilVisible(
        find.text("I've placed it as suggested"),
        220,
        scrollable: _vertical,
      );
      await tester.ensureVisible(find.text("I've placed it as suggested"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("I've placed it as suggested"));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(store.garden.plants, isEmpty);
    },
  );
  testWidgets(
    'all three actions save once, appear once in timeline and can be edited/removed',
    (tester) async {
      var writes = 0;
      final store = makeStore(
        persist: (_) async {
          writes++;
        },
      );
      await open(tester, SoilCareScreen(store: store, plantId: 'p'));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      for (final action in SoilCareAction.values) {
        await soilAction(tester, action.label);
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(writes, 1);
      expect(store.garden.soilCare, hasLength(1));
      expect(store.garden.soilCare.single.actions, hasLength(3));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await open(tester, PlantTimelineScreen(store: store, plantId: 'p'));
      await tester.tap(find.text(store.garden.soilCare.single.title));
      await tester.pumpAndSettle();
      expect(find.text('Edit soil care'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Remove record'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove record'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove record'));
      await tester.pumpAndSettle();
      expect(store.garden.soilCare, isEmpty);
      expect(find.text('No care recorded yet'), findsOneWidget);
    },
  );
  testWidgets('failed soil save retains draft and guarded Back does not save', (
    tester,
  ) async {
    final store = makeStore(
      persist: (_) async {
        throw StateError('disk');
      },
    );
    await open(tester, SoilCareScreen(store: store, plantId: 'p'));
    await soilAction(tester, 'Repotted');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.text("Your soil care couldn't be saved. Try again."),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
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
    expect(store.garden.soilCare, isEmpty);
  });
  testWidgets('soil action form fits narrow large-text dark screens', (
    tester,
  ) async {
    final store = makeStore();
    await open(tester, SoilCareScreen(store: store, plantId: 'p'), large: true);
    await soilAction(tester, 'Refreshed potting mix');
    await tester.scrollUntilVisible(
      find.text('Does the fresh mix contain fertilizer?'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timeline and combined long actions fit narrow large-text dark layout',
    (tester) async {
      final event = SoilCareEvent(
        id: 'job',
        plantId: 'p',
        occurredOn: now,
        recordedAt: now,
        actions: SoilCareAction.values.toSet(),
        notes: 'Refreshed mix and moved to a suitable pot.',
      );
      final store = makeStore(events: [event]);
      await open(
        tester,
        PlantTimelineScreen(store: store, plantId: 'p'),
        large: true,
      );
      await tester.scrollUntilVisible(
        find.text(event.title),
        120,
        scrollable: _vertical,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

final _vertical = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
