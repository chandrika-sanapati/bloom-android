import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/data/watering_notifications.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/watering_notification.dart';
import 'package:bloom/main.dart';
import 'package:bloom/ui/check_screen.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:bloom/ui/preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_notifications.dart';

void main() {
  final species = PlantSpecies.catalog[3];
  final plant = Plant(
    id: 'p',
    name: 'Fern corner',
    species: species.scientific,
    asset: species.asset,
  );
  final schedule = WateringSchedule(
    plantId: 'p',
    intervalDays: 14,
    nextCheckAt: DateTime(2099, 11, 17, 9),
    createdAt: DateTime(2026, 11, 15),
    updatedAt: DateTime(2026, 11, 15),
    timeSource: CheckTimeSource.preference,
  );
  final garden = Garden(plants: [plant], schedules: [schedule]);
  GardenStore store({Future<void> Function(Garden)? persist}) =>
      GardenStore(garden: garden, persist: persist ?? (_) async {});
  WateringNotifications notifications(FakeNotificationClient client) =>
      WateringNotifications(client: client, timezone: () async => 'UTC');

  setUp(() {
    SharedPreferences.setMockInitialValues({'hasSeenAddPlantHint': true});
  });

  Future<void> pick(WidgetTester tester, {bool cancel = false}) async {
    await tester.tap(find.text('Reminder time'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    if (cancel) {
      await tester.tap(find.text('Cancel'));
    } else {
      await tester.tap(find.byTooltip('Switch to text input mode'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '18');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> preferences(
    WidgetTester tester,
    GardenStore store,
    WateringNotifications service, {
    bool large = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: large ? ThemeData.dark(useMaterial3: true) : null,
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(
          alwaysUse24HourFormat: true,
          textScaler: TextScaler.linear(large ? 2 : 1),
        ),
        child: child!,
      ),
      home: PreferencesScreen(store: store, notifications: service),
    ),
  );

  testWidgets(
    'native time picker cancel is no-op; save works while notifications off without permission',
    (tester) async {
      var writes = 0;
      final state = store(
        persist: (_) async {
          writes++;
        },
      );
      final client = FakeNotificationClient()..granted = false;
      await preferences(tester, state, notifications(client));
      expect(find.text('09:00'), findsOneWidget);
      await pick(tester, cancel: true);
      expect(writes, 0);
      await pick(tester);
      expect(state.garden.preferences.reminderHour, 18);
      expect(state.garden.preferences.reminderMinute, 30);
      expect(find.text('18:30'), findsOneWidget);
      expect(client.permissionRequests, 0);
      expect(state.garden.preferences.taskNotifications, isFalse);
      expect(writes, 1);
    },
  );
  testWidgets('failed save retains saved time and can retry', (tester) async {
    var fail = true;
    final state = store(
      persist: (_) async {
        if (fail) throw StateError('disk');
      },
    );
    await preferences(tester, state, notifications(FakeNotificationClient()));
    await pick(tester);
    expect(find.text('09:00'), findsOneWidget);
    expect(
      find.text("Your reminder time couldn't be saved. Try again."),
      findsOneWidget,
    );
    fail = false;
    await pick(tester);
    expect(find.text('18:30'), findsOneWidget);
  });
  testWidgets(
    'denied permission leaves notifications off and reminder time available',
    (tester) async {
      final state = store();
      final client = FakeNotificationClient()..granted = false;
      await preferences(tester, state, notifications(client));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(state.garden.preferences.taskNotifications, isFalse);
      expect(client.permissionRequests, 1);
      expect(
        find.text(
          'Notifications are off in Android settings. Your checks stay in Bloom.',
        ),
        findsOneWidget,
      );
      await pick(tester);
      expect(state.garden.preferences.reminderHour, 18);
      expect(client.permissionRequests, 1);
    },
  );

  testWidgets('enabled reminders show Android settings recovery when denied', (
    tester,
  ) async {
    final state = store();
    final client = FakeNotificationClient()..granted = false;
    final service = notifications(client);
    await preferences(tester, state, service);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    // The preference remains off when permission is denied, so the in-app
    // recovery card is only shown after a saved enabled preference. Simulate
    // the persisted state used when permission is revoked in Android settings.
    state.garden.preferences;
    final enabledState = GardenStore(
      garden: state.garden.copyWith(
        preferences: state.garden.preferences.copyWith(taskNotifications: true),
      ),
      persist: (_) async {},
    );
    await preferences(tester, enabledState, service);
    await service.refreshPermission();
    await tester.pumpAndSettle();
    expect(find.text('Android notifications are off'), findsOneWidget);
    expect(find.text('Open Android settings'), findsOneWidget);
    expect(enabledState.garden.preferences.taskNotifications, isTrue);
  });

  testWidgets('preferences fit a narrow large-text dark screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await preferences(
      tester,
      store(),
      notifications(FakeNotificationClient()),
      large: true,
    );
    await tester.scrollUntilVisible(
      find.text('Turn on watering notifications to receive reminders.'),
      180,
    );
    expect(tester.takeException(), isNull);
  });

  Future<void> app(
    WidgetTester tester,
    GardenStore state,
    WateringNotifications service,
  ) async {
    await tester.pumpWidget(
      BloomApp(store: state, flags: FirstRunFlags(), notifications: service),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cold reminder opens current check once; Back returns Home without writes',
    (tester) async {
      final client = FakeNotificationClient()
        ..startupPayload = WateringNotificationTarget.encode(schedule, 'UTC')
        ..duplicateStartup = true;
      var writes = 0;
      final state = store(
        persist: (_) async {
          writes++;
        },
      );
      await app(tester, state, notifications(client));
      expect(find.byType(CheckScreen), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNull,
      );
      client.tap!(client.startupPayload);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckScreen), findsNothing);
      expect(find.text('My plants'), findsOneWidget);
      expect(writes, 0);
      expect(state.garden.records, isEmpty);
    },
  );
  testWidgets(
    'warm tap reuses manually opened same check and preserves selected outcome',
    (tester) async {
      final client = FakeNotificationClient();
      final state = store();
      await app(tester, state, notifications(client));
      // Open the task from Home using the same route identity as notification entry.
      await tester.tap(find.text('Check watering').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checked — not watered'));
      await tester.pumpAndSettle();
      final before = tester.state(find.byType(CheckScreen));
      client.tap!(WateringNotificationTarget.encode(schedule, 'UTC'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CheckScreen)), same(before));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      expect(state.garden.records, isEmpty);
    },
  );
  testWidgets(
    'warm entry keeps Preferences underneath; stale and legacy go to detail; invalid recovers Home',
    (tester) async {
      final client = FakeNotificationClient();
      final state = store();
      await app(tester, state, notifications(client));
      await tester.tap(find.byTooltip('Preferences'));
      await tester.pumpAndSettle();
      client.tap!(WateringNotificationTarget.encode(schedule, 'UTC'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PreferencesScreen), findsOneWidget);
      client.tap!('bloom-watering-p');
      await tester.pumpAndSettle();
      expect(find.byType(PlantDetailScreen), findsOneWidget);
      expect(
        find.text('This reminder is out of date. Here is the current plan.'),
        findsOneWidget,
      );
      client.tap!('malformed');
      await tester.pumpAndSettle();
      expect(find.byType(PlantDetailScreen), findsNothing);
      expect(find.byType(PreferencesScreen), findsNothing);
      expect(
        find.text('This watering reminder is no longer available.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'unavailable reminder preserves a dirty care form and its discard guard',
    (tester) async {
      final client = FakeNotificationClient();
      final state = store();
      await app(tester, state, notifications(client));
      await tester.tap(find.text('Check watering').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checked — not watered'));
      await tester.pumpAndSettle();
      client.tap!('malformed');
      await tester.pumpAndSettle();
      expect(find.byType(CheckScreen), findsOneWidget);
      expect(state.garden.records, isEmpty);
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
    },
  );

  testWidgets('target deletion while open retains Home recovery', (
    tester,
  ) async {
    final client = FakeNotificationClient()
      ..startupPayload = WateringNotificationTarget.encode(schedule, 'UTC');
    final state = store();
    await app(tester, state, notifications(client));
    await state.deletePlant('p');
    await tester.pumpAndSettle();
    expect(find.text('Watering task unavailable'), findsOneWidget);
    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckScreen), findsNothing);
  });
}
