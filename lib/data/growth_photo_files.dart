import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/garden_store.dart';
import '../domain/models.dart';

/// Captures growth photos and keeps their files in app-private storage.
class GrowthPhotoFiles {
  GrowthPhotoFiles._();

  static final _picker = ImagePicker();

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'growth_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Picks a photo and records it. Returns null if cancelled; throws on failure.
  static Future<GrowthPhoto?> capture(
    GardenStore store,
    String plantId,
    ImageSource source,
  ) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return adopt(store, plantId, picked.path);
  }

  /// Copies an existing image (e.g. the identification photo) into private
  /// storage and records it; optionally makes it the plant image.
  static Future<GrowthPhoto> adopt(
    GardenStore store,
    String plantId,
    String sourcePath, {
    bool asCover = false,
  }) async {
    final now = DateTime.now();
    final id = 'photo-${now.microsecondsSinceEpoch}';
    final dir = await _dir();
    final ext = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final target = p.join(dir.path, '$id$ext');
    await File(sourcePath).copy(target);
    final photo = GrowthPhoto(
      id: id,
      plantId: plantId,
      takenAt: now,
      path: target,
    );
    if (!await store.addGrowthPhoto(photo)) {
      await _deleteQuietly(target);
      throw StateError('Photo could not be saved.');
    }
    if (asCover) await store.setCoverPhoto(plantId, photo.id);
    return photo;
  }

  static Future<bool> remove(GardenStore store, GrowthPhoto photo) async {
    final removed = await store.removeGrowthPhoto(photo.id);
    if (removed) await _deleteQuietly(photo.path);
    return removed;
  }

  /// Deletes files for photos no longer referenced (e.g. after plant removal).
  static Future<void> deleteFiles(Iterable<GrowthPhoto> photos) async {
    for (final photo in photos) {
      await _deleteQuietly(photo.path);
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover private file is harmless; the record is already gone.
    }
  }
}
