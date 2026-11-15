import 'dart:async';

import 'package:flutter/material.dart';

import 'data/garden_repository.dart';
import 'data/watering_notifications.dart';
import 'domain/garden_store.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = GardenRepository();
  final garden = await repository.load();
  final notifications = WateringNotifications();
  final store = GardenStore(
    garden: garden,
    persist: repository.save,
    onChanged: (next) => notifications.sync(
      enabled: next.preferences.taskNotifications,
      plants: next.plants,
      schedules: next.schedules,
    ),
  );
  runApp(
    BloomApp(
      store: store,
      flags: FirstRunFlags(),
      notifications: notifications,
    ),
  );
  unawaited(
    notifications.sync(
      enabled: garden.preferences.taskNotifications,
      plants: garden.plants,
      schedules: garden.schedules,
    ),
  );
}

class BloomApp extends StatelessWidget {
  const BloomApp({
    super.key,
    required this.store,
    required this.flags,
    required this.notifications,
  });

  final GardenStore store;
  final FirstRunFlags flags;
  final WateringNotifications notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF007A73),
        useMaterial3: true,
      ),
      home: HomeScreen(
        store: store,
        flags: flags,
        notifications: notifications,
      ),
    );
  }
}
