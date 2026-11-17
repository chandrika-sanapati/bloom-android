import 'package:flutter/material.dart';

import '../domain/garden_store.dart';
import '../domain/models.dart';
import '../domain/plant_activity.dart';
import '../data/growth_photo_files.dart';
import 'check_screen.dart';
import 'growth_photos.dart';
import 'check_route.dart';
import 'light_placement_section.dart';
import 'widgets.dart';
import 'plant_timeline_screen.dart';
import 'soil_health_section.dart';

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
        final schedule = store.scheduleFor(plantId);
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
        return _Body(store: store, plant: plant, schedule: schedule);
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

class _BodyState extends State<_Body> {
  bool _savingLight = false;

  GardenStore get store => widget.store;
  Plant get plant => widget.plant;
  WateringSchedule? get schedule => widget.schedule;

  Future<void> _saveLightPlacement(bool value) async {
    if (_savingLight) return;
    setState(() => _savingLight = true);
    final saved = await store.setLightPlacementAcknowledged(plant.id, value);
    if (!mounted) return;
    setState(() => _savingLight = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save placement. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastWatered = store.lastWatered(plant.id);
    final records = store.recordsFor(plant.id);
    final lastCheck = records.isEmpty ? null : records.first;
    final species = PlantSpecies.forPlant(plant);
    final recent = PlantActivity.forPlant(store.garden, plant.id);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: 'More options',
            onSelected: (action) => switch (action) {
              _MenuAction.edit => _editPlant(context),
              _MenuAction.photo => addGrowthPhoto(context, store, plant.id),
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
              const PopupMenuItem(
                value: _MenuAction.photo,
                child: ListTile(
                  leading: Icon(Icons.add_a_photo_outlined),
                  title: Text('Take a new photo'),
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PlantImage(store: store, plant: plant, height: 220),
          ),
          const SizedBox(height: 16),
          Text(plant.name, style: theme.textTheme.headlineMedium),
          Text(
            plant.species,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (schedule == null)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Care guidance for this plant isn't available yet.",
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else
            _WateringCard(
              store: store,
              plant: plant,
              schedule: schedule!,
              lastCheck: lastCheck,
              lastWatered: lastWatered,
              careCue: species?.hasCareProfile == true
                  ? species!.careCue
                  : null,
            ),
          const SizedBox(height: 16),
          GrowthSection(store: store, plant: plant),
          if (species case final profile? when profile.hasCareProfile) ...[
            const SizedBox(height: 16),
            LightPlacementSection(
              compact: true,
              guidance: profile.light,
              acknowledged: plant.lightPlacement != null,
              saving: _savingLight,
              earlierGuidance:
                  plant.lightPlacement != null &&
                  plant.lightPlacement!.guidanceVersion !=
                      profile.light.version,
              onChanged: _saveLightPlacement,
            ),
          ],
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: const Text('Care timeline'),
                  trailing: Text(
                    recent.isEmpty ? '' : 'See all',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PlantTimelineScreen(store: store, plantId: plant.id),
                    ),
                  ),
                ),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'No care recorded yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      children: [
                        for (final entry in recent.take(3))
                          HistoryRow(
                            plant: plant,
                            entry: entry,
                            showPlantName: false,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoilHealthSection(store: store, plantId: plant.id),
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

enum _MenuAction { edit, photo, delete }

class _WateringCard extends StatelessWidget {
  const _WateringCard({
    required this.store,
    required this.plant,
    required this.schedule,
    required this.lastCheck,
    required this.lastWatered,
    required this.careCue,
  });

  final GardenStore store;
  final Plant plant;
  final WateringSchedule schedule;
  final WateringRecord? lastCheck;
  final DateTime? lastWatered;
  final String? careCue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timing = CareTaskTiming.classify(schedule.nextCheckAt);
    final due = timing != CareTaskTiming.upcoming;
    return Card(
      margin: EdgeInsets.zero,
      color: due ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Next check',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              due
                  ? '${timing.label} · ${formatDateTime(schedule.nextCheckAt)}'
                  : formatDateTime(schedule.nextCheckAt),
              style: theme.textTheme.titleLarge,
            ),
            if (careCue != null) ...[
              const SizedBox(height: 6),
              Text(
                careCue!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: wateringCheckSettings(schedule),
                  builder: (_) => CheckScreen(store: store, plantId: plant.id),
                ),
              ),
              icon: const Icon(Icons.water_drop),
              label: const Text('Check watering'),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Last check',
              value: lastCheck == null
                  ? 'Not yet'
                  : [
                      lastCheck!.outcome == WateringOutcome.watered
                          ? 'Watered'
                          : 'Not watered',
                      if (lastCheck!.soil != Soil.unknown)
                        'soil ${lastCheck!.soil.label.toLowerCase()}',
                      formatMonthDay(lastCheck!.recordedAt.toLocal()),
                    ].join(' · '),
            ),
            if (lastCheck?.outcome != WateringOutcome.watered)
              _InfoRow(
                label: 'Last watered',
                value: lastWatered == null
                    ? 'Not recorded'
                    : formatDate(lastWatered!),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => pickNextCheck(context, store, plant.id),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Edit next check'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(label),
          subtitle: stack ? valueText : null,
          trailing: stack ? null : valueText,
        );
      },
    );
  }
}
