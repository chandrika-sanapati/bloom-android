import 'package:flutter/material.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import '../domain/plant_activity.dart';
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
      return Scaffold(
        appBar: AppBar(title: const Text('Care timeline')),
        body: plant == null
            ? Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Plant unavailable · Go to Home'),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plant.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text('Recorded care, newest first.'),
                          if (entries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 24),
                              child: EmptyActivityCard(
                                title: 'No care recorded yet',
                                detail:
                                    'Recorded checks and care will appear here.',
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                  final entry = entries[index - 1];
                  final isLatestWatering =
                      entry.watering?.id == latestWateringId;
                  final (title, detail, icon) = switch (entry.kind) {
                    PlantActivityKind.watered => (
                      'Watered',
                      'Soil: ${entry.watering!.soil.label}',
                      Icons.water_drop_outlined,
                    ),
                    PlantActivityKind.checked => (
                      'Checked — not watered',
                      'Soil: ${entry.watering!.soil.label}',
                      Icons.visibility_outlined,
                    ),
                    PlantActivityKind.placement => (
                      'Light placement acknowledged',
                      'Your current saved confirmation. Earlier placement changes are not recorded.',
                      Icons.wb_sunny_outlined,
                    ),
                    PlantActivityKind.soilCare => (
                      entry.soilCare!.title,
                      [
                        if (entry.soilCare!.product != null)
                          entry.soilCare!.product!,
                        if (entry.soilCare!.mixContainsFeed
                            case final bool contains)
                          'Fresh mix contains fertilizer: ${contains ? 'Yes' : 'No'}',
                        if (entry.soilCare!.notes != null)
                          entry.soilCare!.notes!,
                        'Tap to edit this record.',
                      ].join('\n'),
                      Icons.eco_outlined,
                    ),
                  };
                  final local = entry.date.toLocal();
                  final date = MaterialLocalizations.of(
                    context,
                  ).formatFullDate(local);
                  final time = MaterialLocalizations.of(context)
                      .formatTimeOfDay(
                        TimeOfDay.fromDateTime(local),
                        alwaysUse24HourFormat:
                            MediaQuery.alwaysUse24HourFormatOf(context),
                      );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(icon),
                      title: Text(title),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.kind == PlantActivityKind.soilCare
                                  ? date
                                  : '$date · $time',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.watering != null && isLatestWatering
                                  ? '$detail\nTap to delete this latest watering record.'
                                  : detail,
                            ),
                          ],
                        ),
                      ),
                      onTap: entry.soilCare != null
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SoilCareScreen(
                                  store: store,
                                  plantId: plantId,
                                  event: entry.soilCare,
                                ),
                              ),
                            )
                          : entry.watering?.id == latestWateringId
                          ? () => _confirmDeleteLatestWatering(
                              context,
                              store,
                              plantId,
                              entry.watering!,
                            )
                          : null,
                    ),
                  );
                },
              ),
      );
    },
  );
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
        'Delete this latest watering record? Last watered and the next check '
        'may change. A later custom next-check edit is preserved. Soil-care '
        'records are not affected. This cannot be undone.',
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
  if (!context.mounted || deleted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("The record couldn't be deleted.")),
  );
}
