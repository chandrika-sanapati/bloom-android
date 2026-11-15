import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'data/garden_repository.dart';
import 'data/watering_notifications.dart';
import 'domain/garden_store.dart';
import 'ui/home_screen.dart';
import 'ui/check_screen.dart';
import 'ui/check_route.dart';
import 'ui/plant_detail_screen.dart';
import 'domain/watering_notification.dart';

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
}

class BloomApp extends StatefulWidget {
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
  State<BloomApp> createState() => _BloomAppState();
}

class _TopRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  Route<dynamic>? get top => _routes.isEmpty ? null : _routes.last;
  bool get protectsDraft =>
      _routes.any((r) => r.popDisposition == RoutePopDisposition.doNotPop);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = _routes.indexOf(oldRoute!);
    if (index >= 0 && newRoute != null) _routes[index] = newRoute;
  }
}

class _BloomAppState extends State<BloomApp> with WidgetsBindingObserver {
  static const _brandSeed = Color(0xFF007A73);
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _observer = _TopRouteObserver();
  bool _navigationQueued = false;
  String? _payload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.notifications.onTap = _receive;
    unawaited(_sync());
  }

  @override
  void dispose() {
    widget.notifications.onTap = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  Future<void> _sync() {
    final garden = widget.store.garden;
    return widget.notifications.sync(
      enabled: garden.preferences.taskNotifications,
      plants: garden.plants,
      schedules: garden.schedules,
    );
  }

  void _receive(String? payload) {
    _payload = payload;
    if (_navigationQueued) return;
    _navigationQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationQueued = false;
      if (!mounted) return;
      _openReminder(_payload);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _openReminder(String? payload) {
    final navigator = _navigator.currentState;
    if (navigator == null) {
      _receive(payload);
      return;
    }
    final target = ReminderRoute.resolve(payload, widget.store.garden);
    switch (target.destination) {
      case ReminderDestination.check:
        final settings = wateringCheckSettings(target.schedule!);
        if (_observer.top?.settings.name == settings.name &&
            _observer.top?.settings.arguments == settings.arguments) {
          return;
        }
        navigator.push(
          MaterialPageRoute<void>(
            settings: settings,

            builder: (_) =>
                CheckScreen(store: widget.store, plantId: target.plantId!),
          ),
        );
      case ReminderDestination.detail:
        final name = '/plant/${target.plantId}';
        if (_observer.top?.settings.name != name) {
          navigator.push(
            MaterialPageRoute<void>(
              settings: RouteSettings(name: name),
              builder: (_) => PlantDetailScreen(
                store: widget.store,
                plantId: target.plantId!,
              ),
            ),
          );
        }
        _feedback('This reminder is out of date. Here is the current plan.');
      case ReminderDestination.home:
        if (!_observer.protectsDraft) {
          navigator.popUntil((route) => route.isFirst);
        }
        _feedback('This watering reminder is no longer available.');
    }
  }

  void _feedback(String message) {
    _messenger.currentState?.hideCurrentSnackBar();
    _messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

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
          navigatorKey: _navigator,
          scaffoldMessengerKey: _messenger,
          navigatorObservers: [_observer],
          title: 'Bloom',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: HomeScreen(
            store: widget.store,
            flags: widget.flags,
            notifications: widget.notifications,
          ),
        );
      },
    );
  }
}
