import 'dart:io';
import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/data/watering_notifications.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/watering_notification.dart';
import 'package:bloom/main.dart';
import 'package:bloom/ui/check_screen.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bloom.integration/notifications');
  testWidgets(
    'persist preference; native notification intents in foreground/background, stale/deleted fallback',
    (tester) async {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/bloom-reminders-device-test.json');
      if (await file.exists()) await file.delete();
      final repository = GardenRepository(file: file);
      final plugin = FlutterLocalNotificationsPlugin();
      final notifications = WateringNotifications(plugin: plugin);
      final store = GardenStore(
        garden: const Garden(),
        persist: repository.save,
        onChanged: (g) => notifications.sync(
          enabled: g.preferences.taskNotifications,
          plants: g.plants,
          schedules: g.schedules,
        ),
      );
      final species = PlantSpecies.catalog[3];
      final plant = Plant(
        id: 'device-plant',
        name: 'Reminder test Pothos',
        species: species.scientific,
        asset: species.asset,
      );
      final now = DateTime.now();
      await store.addPlant(
        plant,
        lastWatered: now.subtract(const Duration(days: 1)),
        now: now,
      );
      await store.setReminderTime(18, 30);
      final automatic = store.scheduleFor(plant.id)!;
      expect(automatic.nextCheckAt.hour, 18);
      expect(automatic.nextCheckAt.minute, 30);
      await store.editNextCheck(plant.id, now.add(const Duration(days: 2)));
      final custom = store.scheduleFor(plant.id)!;
      await store.setReminderTime(7, 15);
      final reloaded = await repository.load();
      expect(reloaded.preferences.reminderHour, 7);
      expect(reloaded.schedules.single.timeSource, CheckTimeSource.custom);
      expect(reloaded.schedules.single.nextCheckAt, custom.nextCheckAt);
      await tester.pumpWidget(
        BloomApp(
          store: store,
          flags: FirstRunFlags(),
          notifications: notifications,
        ),
      );
      await tester.pumpAndSettle();
      // Permission is granted to this isolated package by the external runner.
      expect(await notifications.hasPermission(), isTrue);
      await store.setTaskNotifications(true);
      expect(await plugin.pendingNotificationRequests(), hasLength(1));
      await tester.tap(find.byTooltip('Preferences'));
      await tester.pumpAndSettle();
      expect(find.text('Reminder time'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await File(
        '${directory.path}/bloom-reminder-preferences.png',
      ).writeAsBytes(await binding.takeScreenshot('reminder-preferences'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      Future<void> postAndTap(String payload, {bool background = false}) async {
        await plugin.show(
          id: 440,
          title: 'Check watering',
          body: 'Check the test plant soil.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'watering_checks',
              'Watering checks',
            ),
          ),
          payload: payload,
        );
        if (background) await channel.invokeMethod<bool>('backgroundApp');
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          expect(
            await channel.invokeMethod<bool>('tapNotification', {'id': 440}),
            isTrue,
          );
          await Future<void>.delayed(const Duration(milliseconds: 350));
        });
        await tester.pumpAndSettle();
      }

      final payload = WateringNotificationTarget.encode(custom, 'test');
      await postAndTap(payload);
      expect(find.byType(CheckScreen), findsOneWidget);
      expect(store.garden.records, isEmpty);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await postAndTap(payload, background: true);
      expect(find.byType(CheckScreen), findsOneWidget);
      await File(
        '${directory.path}/bloom-reminder-check.png',
      ).writeAsBytes(await binding.takeScreenshot('reminder-check'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await store.editNextCheck(plant.id, now.add(const Duration(days: 3)));
      await postAndTap(payload);
      expect(find.byType(PlantDetailScreen), findsOneWidget);
      expect(
        find.text('This reminder is out of date. Here is the current plan.'),
        findsOneWidget,
      );
      await store.deletePlant(plant.id);
      await postAndTap(payload);
      expect(find.byType(PlantDetailScreen), findsNothing);
      expect(
        find.text('This watering reminder is no longer available.'),
        findsOneWidget,
      );
      expect(store.garden.records, isEmpty);
      await plugin.cancelAll();
      await file.delete();
    },
  );
}
