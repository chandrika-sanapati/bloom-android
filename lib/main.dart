import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

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

  static const _brandSeed = Color(0xFF007A73);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: _brandSeed,
              brightness: Brightness.light,
            );
        final darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _brandSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Bloom',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: HomeScreen(
            store: store,
            flags: flags,
            notifications: notifications,
          ),
        );
      },
    );
  }
}
