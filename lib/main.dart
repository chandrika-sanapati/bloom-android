import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/garden_repository.dart';
import 'data/auth_service.dart';
import 'data/cloud_garden_sync.dart';
import 'data/plant_identifier.dart';
import 'data/plant_profile_catalog.dart';
import 'data/watering_notifications.dart';
import 'domain/garden_store.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/check_screen.dart';
import 'ui/check_route.dart';
import 'ui/plant_detail_screen.dart';
import 'domain/watering_notification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeSupabaseIfConfigured();
  await PlantProfileCatalog.load();
  final repository = GardenRepository();
  final garden = await repository.load();
  final notifications = WateringNotifications();
  final identifier = configuredPlantIdentifier();
  final auth = configuredAuthService();
  final cloudSync = CloudGardenSync();
  final store = GardenStore(
    garden: garden,
    persist: repository.save,
    onChanged: (next) async {
      await notifications.sync(
        enabled: next.preferences.taskNotifications,
        plants: next.plants,
        schedules: next.schedules,
      );
    },
    onPersisted: cloudSync.sync,
  );
  runApp(
    BloomApp(
      store: store,
      flags: FirstRunFlags(),
      notifications: notifications,
      identifier: identifier,
      auth: auth,
      cloudSync: cloudSync,
    ),
  );
}

Future<void> _initializeSupabaseIfConfigured() async {
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || publishableKey.isEmpty) return;
  try {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  } catch (_) {
    // Cloud services are optional; keep the local-first app available.
  }
}

class BloomApp extends StatefulWidget {
  const BloomApp({
    super.key,
    required this.store,
    required this.flags,
    required this.notifications,
    this.auth,
    required this.cloudSync,
    this.identifier,
  });

  final GardenStore store;
  final FirstRunFlags flags;
  final WateringNotifications notifications;
  final PlantIdentifier? identifier;
  final AuthService? auth;
  final CloudGardenSync cloudSync;

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
  static const _brandSeed = Color(0xFF2E6B3A);
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
    return Future.wait([
      widget.notifications.sync(
        enabled: garden.preferences.taskNotifications,
        plants: garden.plants,
        schedules: garden.schedules,
      ),
      widget.cloudSync.sync(garden),
    ]).then((_) {});
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
    return Builder(
      builder: (context) {
        // Fixed Bloom green; wallpaper-based dynamic color is not used.
        final lightScheme = ColorScheme.fromSeed(
          seedColor: _brandSeed,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: _brandSeed,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );

        return MaterialApp(
          navigatorKey: _navigator,
          scaffoldMessengerKey: _messenger,
          navigatorObservers: [_observer],
          title: 'Bloom',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _NoStretchScrollBehavior(),
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: _AuthGate(
            store: widget.store,
            flags: widget.flags,
            notifications: widget.notifications,
            identifier: widget.identifier,
            auth: widget.auth,
            cloudSync: widget.cloudSync,
          ),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.store,
    required this.flags,
    required this.notifications,
    required this.identifier,
    required this.auth,
    required this.cloudSync,
  });

  final GardenStore store;
  final FirstRunFlags flags;
  final WateringNotifications notifications;
  final PlantIdentifier? identifier;
  final AuthService? auth;
  final CloudGardenSync cloudSync;

  @override
  Widget build(BuildContext context) {
    final service = auth;
    if (service == null || !service.configured) {
      return HomeScreen(
        store: store,
        flags: flags,
        notifications: notifications,
        identifier: identifier,
        auth: auth,
        cloudSync: cloudSync,
      );
    }

    return StreamBuilder<AuthState>(
      stream: service.authStateChanges,
      builder: (context, _) {
        if (service.signedIn) {
          return HomeScreen(
            store: store,
            flags: flags,
            notifications: notifications,
            identifier: identifier,
            auth: auth,
            cloudSync: cloudSync,
          );
        }
        return LoginScreen(auth: service, cloudSync: cloudSync, store: store);
      },
    );
  }
}

/// Removes the Android stretch ("rubber band") overscroll effect app-wide.
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
