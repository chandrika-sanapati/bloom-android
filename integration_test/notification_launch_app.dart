// Standalone cold-launch fixture, built only into the isolated integration APK.
// It uses the production app/service and reports mounted destinations for the
// external runner after a real Android notification PendingIntent launches it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/data/cloud_garden_sync.dart';
import 'package:bloom/data/watering_notifications.dart';
import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/watering_notification.dart';
import 'package:bloom/main.dart';
import 'package:bloom/ui/check_screen.dart';
import 'package:bloom/ui/plant_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getTemporaryDirectory();
  final repository = GardenRepository(
    file: File('${directory.path}/cold-launch-garden.json'),
  );
  var garden = await repository.load();
  if (garden.plants.isEmpty) {
    final species = PlantSpecies.catalog[3];
    final now = DateTime.now();
    garden = Garden(
      plants: [
        Plant(
          id: 'cold-plant',
          name: 'Cold launch Pothos',
          species: species.scientific,
          asset: species.asset,
        ),
      ],
      schedules: [
        WateringSchedule(
          plantId: 'cold-plant',
          intervalDays: 14,
          nextCheckAt: now.add(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await repository.save(garden);
  }
  final store = GardenStore(garden: garden, persist: repository.save);
  final plugin = FlutterLocalNotificationsPlugin();
  final notifications = WateringNotifications(plugin: plugin);
  runApp(
    BloomApp(
      store: store,
      flags: FirstRunFlags(),
      notifications: notifications,
      cloudSync: CloudGardenSync(),
    ),
  );
  await notifications.init();
  final idFile = File('${directory.path}/cold-notification-id');
  final notificationId = int.parse(await idFile.readAsString());
  final payload = switch (notificationId) {
    441 => WateringNotificationTarget.encode(garden.schedules.single, 'test'),
    442 => 'bloom-watering-cold-plant',
    443 => 'malformed',
    _ => 'bloom-watering-deleted-plant',
  };
  await plugin.cancelAll();
  await plugin.show(
    id: notificationId,
    title: 'Check & water',
    body: 'Cold launch test $notificationId',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails('watering_checks', 'Watering checks'),
    ),
    payload: payload,
  );
  Timer.periodic(const Duration(milliseconds: 250), (_) {
    var checks = 0;
    var details = 0;
    void visit(Element element) {
      if (element.widget is CheckScreen) checks++;
      if (element.widget is PlantDetailScreen) details++;
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    visit(root);
    File('${directory.path}/cold-launch-result.json').writeAsStringSync(
      jsonEncode({
        'pid': pid,
        'posted': notificationId,
        'checks': checks,
        'details': details,
        'records': store.garden.records.length,
        'unchanged':
            jsonEncode(store.garden.toJson()) == jsonEncode(garden.toJson()),
      }),
    );
  });
}
