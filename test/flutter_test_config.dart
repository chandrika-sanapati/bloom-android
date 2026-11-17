import 'dart:async';

import 'package:bloom/data/plant_profile_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await PlantProfileCatalog.load();
  await testMain();
}
