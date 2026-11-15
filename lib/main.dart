import 'package:flutter/material.dart';

import 'data/garden_repository.dart';
import 'domain/garden_store.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = GardenRepository();
  final garden = await repository.load();
  final store = GardenStore(garden: garden, persist: repository.save);
  runApp(BloomApp(store: store, flags: FirstRunFlags()));
}

class BloomApp extends StatelessWidget {
  const BloomApp({super.key, required this.store, required this.flags});

  final GardenStore store;
  final FirstRunFlags flags;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF007A73),
        useMaterial3: true,
      ),
      home: HomeScreen(store: store, flags: flags),
    );
  }
}
