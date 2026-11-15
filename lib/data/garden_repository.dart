import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Reads and writes the garden as JSON in the app's support directory,
/// matching the iOS `Bloom/garden.json` file.
class GardenRepository {
  GardenRepository({File? file}) : _file = file;

  File? _file;

  Future<File> _resolveFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'Bloom', 'garden.json'));
    _file = file;
    return file;
  }

  Future<Garden> load() async {
    final file = await _resolveFile();
    if (!await file.exists()) return const Garden();
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return Garden.fromJson(json);
    } catch (_) {
      return const Garden();
    }
  }

  Future<void> save(Garden garden) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(garden.toJson()), flush: true);
    await temp.rename(file.path);
  }
}

/// First-run hint flag, matching the iOS `hasSeenAddPlantHint` key.
class FirstRunFlags {
  static const _addPlantHintKey = 'hasSeenAddPlantHint';

  Future<bool> hasSeenAddPlantHint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_addPlantHintKey) ?? false;
  }

  Future<void> markAddPlantHintSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_addPlantHintKey, true);
  }
}
