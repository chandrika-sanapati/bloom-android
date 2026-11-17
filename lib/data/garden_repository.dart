import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';

/// Reads and writes the garden as JSON in the app's support directory.
class GardenRepository {
  // The public `file` name is intentional; `_file` is the lazily resolved cache.
  // ignore: prefer_initializing_formals
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

  /// Path of the backup made when the saved garden couldn't be read.
  String? lastUnreadableBackup;

  Future<Garden> load() async {
    final file = await _resolveFile();
    if (!await file.exists()) return const Garden();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return Garden.fromJson(json);
    } catch (_) {
      // Keep the unreadable data before any later save replaces it, so it can
      // be recovered instead of being silently overwritten by an empty garden.
      lastUnreadableBackup = await _backUpUnreadable(file);
      return const Garden();
    }
  }

  Future<String?> _backUpUnreadable(File file) async {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final backup = File(
      p.join(file.parent.path, 'garden.unreadable-$stamp.json'),
    );
    try {
      await file.copy(backup.path);
      return backup.path;
    } catch (_) {
      return null;
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
