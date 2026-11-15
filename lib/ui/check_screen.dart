import 'package:flutter/material.dart';

import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'widgets.dart';

class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key, required this.store, required this.plantId});

  final GardenStore store;
  final String plantId;

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  WateringOutcome? _outcome;
  Soil _soil = Soil.unknown;
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final outcome = _outcome;
    if (outcome == null) {
      setState(() => _error = 'Choose what you did.');
      return;
    }
    setState(() => _saving = true);
    final record = await widget.store.completeWateringCheck(
      plantId: widget.plantId,
      outcome: outcome,
      soil: _soil,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (record == null) {
      setState(
        () => _error = "Your check couldn't be saved. Please try again.",
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final plant = widget.store.plant(widget.plantId);
        final schedule = widget.store.scheduleFor(widget.plantId);
        if (plant == null || schedule == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Watering task unavailable')),
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Go to Home'),
              ),
            ),
          );
        }
        final theme = Theme.of(context);
        final species = PlantSpecies.forPlant(plant);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Check watering'),
            leading: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            leadingWidth: 96,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: _outcome == null || _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(plant.name, style: theme.textTheme.headlineSmall),
              if (species != null) ...[
                const SizedBox(height: 4),
                Text(
                  species.careCue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Scheduled check: ${formatDateTime(schedule.nextCheckAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () =>
                    pickNextCheck(context, widget.store, widget.plantId),
                icon: const Icon(Icons.calendar_today),
                label: const Text('Edit next check'),
              ),
              const SizedBox(height: 24),
              Text('What did you find?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<Soil>(
                segments: [
                  for (final soil in Soil.values)
                    ButtonSegment(value: soil, label: Text(soil.label)),
                ],
                selected: {_soil},
                onSelectionChanged: (selection) =>
                    setState(() => _soil = selection.first),
              ),
              const SizedBox(height: 24),
              Text('What did you do?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: RadioGroup<WateringOutcome>(
                  groupValue: _outcome,
                  onChanged: (chosen) => setState(() => _outcome = chosen),
                  child: Column(
                    children: [
                      for (final value in WateringOutcome.values)
                        RadioListTile<WateringOutcome>(
                          title: Text(value.label),
                          value: value,
                        ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        );
      },
    );
  }
}
