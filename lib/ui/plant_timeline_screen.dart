import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import '../domain/plant_activity.dart';
import 'growth_photos.dart';
import 'soil_care_screen.dart';
import 'widgets.dart';

class PlantTimelineScreen extends StatelessWidget {
  const PlantTimelineScreen({
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
      final plant = store.plant(plantId);
      final entries = PlantActivity.forPlant(store.garden, plantId);
      final wateringRecords = store.recordsFor(plantId);
      final latestWateringId = wateringRecords.isEmpty
          ? null
          : wateringRecords.first.id;
      if (plant == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Plant unavailable')),
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Go to Home'),
            ),
          ),
        );
      }
      final rows = <Widget>[];
      String? month;
      for (final entry in entries) {
        final local = entry.date.toLocal();
        final label = DateFormat.yMMMM().format(local);
        if (label != month) {
          month = label;
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 20, bottom: 4),
              child: SectionHeader(label),
            ),
          );
        }
        rows.add(
          _TimelineRow(
            store: store,
            plantId: plantId,
            entry: entry,
            isLatestWatering: entry.watering?.id == latestWateringId,
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text('${plant.name} history')),
        body: entries.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyActivityCard(
                  title: 'No care recorded yet',
                  detail: 'Checks, care and photos will appear here.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: rows,
              ),
      );
    },
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.store,
    required this.plantId,
    required this.entry,
    required this.isLatestWatering,
  });

  final GardenStore store;
  final String plantId;
  final PlantActivity entry;
  final bool isLatestWatering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = entry.date.toLocal();
    final when = entry.kind == PlantActivityKind.soilCare
        ? formatMonthDay(local)
        : '${formatMonthDay(local)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
    final (title, details, icon) = switch (entry.kind) {
      PlantActivityKind.watered => ('Watered', <String>[], Icons.water_drop),
      PlantActivityKind.checked => (
        'Checked — not watered',
        ['Soil: ${entry.watering!.soil.label}'],
        Icons.visibility_outlined,
      ),
      PlantActivityKind.placement => (
        'Light placement confirmed',
        <String>[],
        Icons.wb_sunny_outlined,
      ),
      PlantActivityKind.soilCare => (
        entry.soilCare!.title,
        [
          if (entry.soilCare!.product != null) entry.soilCare!.product!,
          if (entry.soilCare!.mixContainsFeed case final bool contains)
            'Fresh mix contains fertilizer: ${contains ? 'Yes' : 'No'}',
          if (entry.soilCare!.notes != null) entry.soilCare!.notes!,
        ],
        Icons.eco_outlined,
      ),
      PlantActivityKind.photo => (
        'Growth photo',
        <String>[],
        Icons.photo_camera_outlined,
      ),
    };
    final VoidCallback? onTap = switch (entry) {
      PlantActivity(photo: final photo?) => () => openGrowthPhoto(
        context,
        store,
        photo,
      ),
      PlantActivity(soilCare: final event?) => () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SoilCareScreen(store: store, plantId: plantId, event: event),
        ),
      ),
      PlantActivity(watering: final record?) when isLatestWatering =>
        () => _confirmDeleteLatestWatering(context, store, plantId, record),
      _ => null,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
      leading: entry.photo != null
          ? GrowthThumbnail(photo: entry.photo!, size: 40)
          : CircleAvatar(
              radius: 20,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(icon, size: 20, color: scheme.onSecondaryContainer),
            ),
      title: Text(title),
      subtitle: Text([when, ...details].join('\n')),
      isThreeLine: details.isNotEmpty,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}

Future<void> _confirmDeleteLatestWatering(
  BuildContext context,
  GardenStore store,
  String plantId,
  WateringRecord record,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${record.outcome.label} record'),
      content: const Text(
        'Delete this record? Last watered and the next check may update.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete record'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final deleted = await store.deleteLatestWateringRecord(plantId, record.id);
  if (!context.mounted) return;
  if (deleted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Watering record deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final restored = await store.undoLatestWateringCorrection();
            if (!context.mounted || restored) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This correction is no longer available.'),
              ),
            );
          },
        ),
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("The record couldn't be deleted.")),
  );
}
