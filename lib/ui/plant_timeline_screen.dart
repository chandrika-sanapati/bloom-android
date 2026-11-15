import 'package:flutter/material.dart';
import '../domain/garden_store.dart';
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
                            Text(detail),
                          ],
                        ),
                      ),
                      onTap: entry.soilCare == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SoilCareScreen(
                                  store: store,
                                  plantId: plantId,
                                  event: entry.soilCare,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
      );
    },
  );
}
