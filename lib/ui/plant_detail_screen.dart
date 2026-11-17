import 'package:flutter/material.dart';

import '../data/growth_photo_files.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import '../domain/plant_activity.dart';
import 'check_route.dart';
import 'check_screen.dart';
import 'growth_photos.dart';
import 'light_placement_section.dart';
import 'plant_timeline_screen.dart';
import 'soil_care_screen.dart';
import 'widgets.dart';

class PlantDetailScreen extends StatelessWidget {
  const PlantDetailScreen({
    super.key,
    required this.store,
    required this.plantId,
  });

  final GardenStore store;
  final String plantId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final plant = store.plant(plantId);
        if (plant == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Plant unavailable')),
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Go to Home'),
              ),
            ),
          );
        }
        return _Body(
          store: store,
          plant: plant,
          schedule: store.scheduleFor(plantId),
        );
      },
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.store,
    required this.plant,
    required this.schedule,
  });

  final GardenStore store;
  final Plant plant;
  final WateringSchedule? schedule;

  @override
  State<_Body> createState() => _BodyState();
}

enum _MenuAction { edit, delete }

class _BodyState extends State<_Body> {
  bool _savingLight = false;

  /// Light panel stays collapsed until the user opens it.
  bool _lightOpen = false;

  GardenStore get store => widget.store;
  Plant get plant => widget.plant;
  WateringSchedule? get schedule => widget.schedule;

  Future<void> _answerLight(bool placed) async {
    if (_savingLight) return;
    setState(() => _savingLight = true);
    var saved = true;
    // Re-confirming after an advice update records the new version.
    if (placed && plant.lightPlacement != null) {
      saved = await store.setLightPlacementAcknowledged(plant.id, false);
    }
    if (saved) {
      saved = await store.setLightPlacementAcknowledged(plant.id, placed);
    }
    if (!mounted) return;
    setState(() => _savingLight = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save placement. Try again.")),
      );
    }
  }

  void _logCare() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SoilCareScreen(store: store, plantId: plant.id),
    ),
  );

  void _openHistory() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlantTimelineScreen(store: store, plantId: plant.id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final species = PlantSpecies.forPlant(plant);
    final profile = species?.hasCareProfile == true ? species : null;
    final history = PlantActivity.forPlant(store.garden, plant.id);
    final photos = store.photosFor(plant.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            leading: Center(
              child: IconButton(
                tooltip: 'Back',
                style: _overImage(context),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            actions: [
              PopupMenuButton<_MenuAction>(
                style: _overImage(context),
                tooltip: 'More options',
                onSelected: (action) => switch (action) {
                  _MenuAction.edit => _editPlant(context),
                  _MenuAction.delete => _confirmRemoval(context),
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _MenuAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.delete,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PlantImage(store: store, plant: plant, height: 280),
                  if (photos.isNotEmpty)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: ActionChip(
                        avatar: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          photos.length == 1
                              ? '1 photo'
                              : '${photos.length} photos',
                        ),
                        onPressed: () =>
                            openGrowthGallery(context, store, plant.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList.list(
              children: [
                Text(plant.name, style: theme.textTheme.headlineMedium),
                Text(
                  plant.species,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _StatusCard(store: store, plant: plant, schedule: schedule),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            addGrowthPhoto(context, store, plant.id),
                        icon: Badge(
                          isLabelVisible: growthPhotoDue(store, plant.id),
                          smallSize: 8,
                          child: const Icon(Icons.photo_camera_outlined),
                        ),
                        label: const Text('Add photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _logCare,
                        icon: const Icon(Icons.eco_outlined),
                        label: const Text('Soil care'),
                      ),
                    ),
                  ],
                ),
                if (profile != null) ...[
                  const SizedBox(height: 28),
                  const _SectionLabel('Care guide'),
                  _GuideRow(
                    icon: Icons.water_drop_outlined,
                    title: profile.careCue,
                  ),
                  _GuideRow(
                    key: const ValueKey('plant-detail-light-guide'),
                    icon: Icons.wb_sunny_outlined,
                    title: profile.light.requirement,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (plant.lightPlacement != null)
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: theme.colorScheme.primary,
                            semanticLabel: 'Placement confirmed',
                          ),
                        Icon(
                          _lightOpen ? Icons.expand_less : Icons.expand_more,
                        ),
                      ],
                    ),
                    onTap: () => setState(() => _lightOpen = !_lightOpen),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: _lightOpen
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: LightPlacementPanel(
                              guidance: profile.light,
                              placement: plant.lightPlacement,
                              saving: _savingLight,
                              onAnswer: _answerLight,
                              onNotYet: () =>
                                  setState(() => _lightOpen = false),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: _SectionLabel('History')),
                    if (history.isNotEmpty)
                      TextButton(
                        onPressed: _openHistory,
                        child: const Text('See all'),
                      ),
                  ],
                ),
                if (history.isEmpty)
                  Text(
                    'Checks, care and photos will appear here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final entry in history.take(5))
                    HistoryRow(
                      plant: plant,
                      entry: entry,
                      showPlantName: false,
                      onTap: _openHistory,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPlant(BuildContext context) async {
    final controller = TextEditingController(text: plant.displayName ?? '');
    final defaultName = PlantSpecies.forPlant(plant)?.name ?? plant.name;
    final photos = store.photosFor(plant.id);
    var coverId = store.coverPhotoFor(plant)?.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Widget option(String? id, Widget image, String label) {
            final selected = coverId == id;
            return Semantics(
              selected: selected,
              button: true,
              label: label,
              child: GestureDetector(
                onTap: () => setDialogState(() => coverId = id),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      width: 3,
                      color: selected
                          ? Theme.of(dialogContext).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: image,
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Edit plant'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: defaultName,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Plant image',
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        option(
                          null,
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              plant.asset,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                            ),
                          ),
                          'Default image',
                        ),
                        for (final photo in photos)
                          option(
                            photo.id,
                            GrowthThumbnail(photo: photo, size: 62),
                            'Photo from ${formatDate(photo.takenAt.toLocal())}',
                          ),
                      ],
                    ),
                  ),
                  if (photos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Add a growth photo to use it as the plant image.',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (result != true || !context.mounted) return;
    final updated = name.isEmpty || name == defaultName
        ? plant.copyWith(clearDisplayName: true)
        : plant.copyWith(displayName: name);
    var saved = true;
    if (updated.displayName != plant.displayName) {
      saved = await store.savePlant(updated);
    }
    if (saved && coverId != plant.coverPhotoId) {
      saved = await store.setCoverPhoto(plant.id, coverId);
    }
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save changes. Try again.")),
      );
    }
  }

  Future<void> _confirmRemoval(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${plant.name}?'),
        content: const Text('Its care history will be deleted too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
    final photos = store.photosFor(plant.id);
    final removed = await store.deletePlant(plant.id);
    if (removed) await GrowthPhotoFiles.deleteFiles(photos);
    if (removed && context.mounted) Navigator.of(context).pop();
  }
}

/// Keeps toolbar icons legible on top of any photo.
ButtonStyle _overImage(BuildContext context) => IconButton.styleFrom(
  backgroundColor: Theme.of(
    context,
  ).colorScheme.surface.withValues(alpha: 0.85),
);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    title: Text(title),
    trailing: trailing,
    onTap: onTap,
  );
}

/// The one place that says when to check next and offers the main action.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.store,
    required this.plant,
    required this.schedule,
  });

  final GardenStore store;
  final Plant plant;
  final WateringSchedule? schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = schedule;
    if (current == null) {
      return Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No care guide yet. You can still log care and add photos.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final now = DateTime.now();
    final due =
        CareTaskTiming.classify(current.nextCheckAt, now: now) !=
        CareTaskTiming.upcoming;
    final background = due
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final foreground = due ? scheme.onPrimaryContainer : scheme.onSurface;
    final lastWatered = store.lastWatered(plant.id);

    return Card(
      margin: EdgeInsets.zero,
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Next check',
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
            Semantics(
              button: true,
              label:
                  'Next check ${relativeCheckLabel(current.nextCheckAt, now)}. Change date',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => pickNextCheck(context, store, plant.id),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        relativeCheckLabel(current.nextCheckAt, now),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.edit_outlined, color: foreground),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              lastWatered == null
                  ? 'Last watered: not recorded'
                  : 'Last watered ${relativeAgo(lastWatered, now)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: wateringCheckSettings(current),
                    builder: (_) =>
                        CheckScreen(store: store, plantId: plant.id),
                  ),
                ),
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('Check & water'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _calendarDays(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inHours ~/ 24;
}

/// "Today", "Tomorrow", "In 5 days · Dec 1", "Overdue · 2 days".
String relativeCheckLabel(DateTime when, DateTime now) {
  final local = when.toLocal();
  final days = _calendarDays(now, local);
  if (local.isBefore(now) && days < 0) {
    return days == -1 ? 'Overdue · 1 day' : 'Overdue · ${-days} days';
  }
  if (days <= 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days · ${formatMonthDay(local)}';
}

/// "today", "yesterday", "9 days ago".
String relativeAgo(DateTime when, DateTime now) {
  final days = _calendarDays(when.toLocal(), now);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}
