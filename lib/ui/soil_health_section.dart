import 'package:flutter/material.dart';
import '../domain/garden_store.dart';
import '../domain/soil_care.dart';
import 'soil_care_screen.dart';
import 'widgets.dart';

/// Records soil care the user has done. Bloom does not diagnose soil health.
class SoilHealthSection extends StatelessWidget {
  const SoilHealthSection({
    super.key,
    required this.store,
    required this.plantId,
  });
  final GardenStore store;
  final String plantId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Soil health', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final action in SoilCareAction.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(action.label)),
                    Text(
                      _last(action),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SoilCareScreen(store: store, plantId: plantId),
                ),
              ),
              icon: const Icon(Icons.add_task),
              label: const Text('Record soil care'),
            ),
          ],
        ),
      ),
    );
  }

  String _last(SoilCareAction action) {
    final events = store
        .soilCareFor(plantId)
        .where((e) => e.actions.contains(action));
    return events.isEmpty ? 'Not yet' : formatDate(events.first.occurredOn);
  }
}
