import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/growth_photo_files.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'widgets.dart';

/// How long before Bloom nudges for a new growth photo.
const growthPhotoInterval = Duration(days: 30);

/// Asks for camera or gallery, saves the photo and offers it as the cover.
Future<void> addGrowthPhoto(
  BuildContext context,
  GardenStore store,
  String plantId,
) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final photo = await GrowthPhotoFiles.capture(store, plantId, source);
    if (photo == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Growth photo added.'),
        persist: false,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Use as plant image',
          onPressed: () => store.setCoverPhoto(plantId, photo.id),
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text("The photo couldn't be saved. Try again.")),
    );
  }
}

class GrowthThumbnail extends StatelessWidget {
  const GrowthThumbnail({super.key, required this.photo, this.size = 72});

  final GrowthPhoto photo;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.file(
      File(photo.path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * 3).round(),
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    ),
  );
}

void openGrowthPhoto(
  BuildContext context,
  GardenStore store,
  GrowthPhoto photo,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => GrowthPhotoScreen(store: store, photoId: photo.id),
  ),
);

class GrowthPhotoScreen extends StatelessWidget {
  const GrowthPhotoScreen({
    super.key,
    required this.store,
    required this.photoId,
  });

  final GardenStore store;
  final String photoId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final matches = store.garden.growthPhotos.where((p) => p.id == photoId);
      if (matches.isEmpty) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Photo unavailable')),
        );
      }
      final photo = matches.first;
      final plant = store.plant(photo.plantId);
      final isCover = plant?.coverPhotoId == photo.id;
      return Scaffold(
        appBar: AppBar(
          title: Text(formatDate(photo.takenAt.toLocal())),
          actions: [
            IconButton(
              tooltip: 'Delete photo',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, photo),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Center(
                  child: Image.file(
                    File(photo.path),
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
            ),
            if (plant != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isCover
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () => store.setCoverPhoto(plant.id, null),
                          child: const Text('Use default plant image'),
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () =>
                              store.setCoverPhoto(plant.id, photo.id),
                          child: const Text('Use as plant image'),
                        ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _delete(BuildContext context, GrowthPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text('It will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await GrowthPhotoFiles.remove(store, photo);
    if (removed && context.mounted) Navigator.of(context).pop();
  }
}

/// True when the plant has no photo or the last one is older than the interval.
bool growthPhotoDue(GardenStore store, String plantId) {
  final photos = store.photosFor(plantId);
  return photos.isEmpty ||
      DateTime.now().difference(photos.first.takenAt) >= growthPhotoInterval;
}

void openGrowthGallery(
  BuildContext context,
  GardenStore store,
  String plantId,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => GrowthGalleryScreen(store: store, plantId: plantId),
  ),
);

/// All growth photos for a plant, oldest first, so growth reads left to right.
class GrowthGalleryScreen extends StatelessWidget {
  const GrowthGalleryScreen({
    super.key,
    required this.store,
    required this.plantId,
  });

  final GardenStore store;
  final String plantId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final photos = store.photosFor(plantId).reversed.toList();
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text('${store.plant(plantId)?.name ?? 'Plant'} growth'),
          actions: [
            IconButton(
              tooltip: 'Add photo',
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: () => addGrowthPhoto(context, store, plantId),
            ),
          ],
        ),
        body: photos.isEmpty
            ? const Center(child: Text('No photos yet'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final date = formatDate(photo.takenAt.toLocal());
                  return Semantics(
                    button: true,
                    label: 'Growth photo, $date',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => openGrowthPhoto(context, store, photo),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: LayoutBuilder(
                              builder: (context, c) => GrowthThumbnail(
                                photo: photo,
                                size: c.maxWidth,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatMonthDay(photo.takenAt.toLocal()),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}
