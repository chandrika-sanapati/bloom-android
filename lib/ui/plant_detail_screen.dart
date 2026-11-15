import 'package:flutter/material.dart';

import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'check_screen.dart';
import 'widgets.dart';

class PlantDetailScreen extends StatelessWidget {
  const PlantDetailScreen({super.key, required this.store, required this.plantId});

  final GardenStore store;
  final String plantId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final plant = store.plant(plantId);
        final schedule = store.scheduleFor(plantId);
        if (plant == null || schedule == null) {
          return const Scaffold(
            body: Center(child: Text('Plant unavailable')),
          );
        }
        return _Body(store: store, plant: plant, schedule: schedule);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.store, required this.plant, required this.schedule});

  final GardenStore store;
  final Plant plant;
  final WateringSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastWatered = store.lastWatered(plant.id);
    final species = PlantSpecies.forPlant(plant);

    return Scaffold(
      appBar: AppBar(title: const Text('Plant')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              plant.asset,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
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
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => CheckScreen(store: store, plantId: plant.id),
              ),
            ),
            icon: const Icon(Icons.water_drop),
            label: const Text('Check watering'),
          ),
          const SizedBox(height: 24),
          Text('Watering', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(label: 'Added', value: formatDate(schedule.createdAt)),
                _InfoRow(
                  label: 'Next check',
                  value: formatDateTime(schedule.nextCheckAt),
                ),
                _InfoRow(
                  label: 'Starting suggestion',
                  value: 'Every ${schedule.intervalDays} days',
                ),
                _InfoRow(
                  label: 'Last watered',
                  value: lastWatered == null ? 'Not recorded' : formatDate(lastWatered),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Edit next check'),
                  onTap: () => pickNextCheck(context, store, plant.id),
                ),
              ],
            ),
          ),
          if (species != null) ...[
            const SizedBox(height: 16),
            Text(
              species.careCue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text(
                'Remove plant',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => _confirmRemoval(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${plant.name}?'),
        content: const Text('This also removes its watering history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Remove plant',
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await store.deletePlant(plant.id);
    if (removed && context.mounted) Navigator.of(context).pop();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
