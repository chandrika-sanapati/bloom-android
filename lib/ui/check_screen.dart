import 'package:flutter/material.dart';

import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'widgets.dart';
import 'discard_changes_guard.dart';

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
  bool _saved = false;

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
      soil: outcome == WateringOutcome.checkedNotWatered ? _soil : Soil.unknown,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (record == null) {
      setState(
        () => _error = "Your check couldn't be saved. Please try again.",
      );
      return;
    }
    setState(() => _saved = true);
    final next = widget.store.scheduleFor(widget.plantId)?.nextCheckAt;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          next == null
              ? '${outcome.label} — saved.'
              : '${outcome.label} — saved. Next check ${formatMonthDay(next)}.',
        ),
      ),
    );
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
        final theme = Theme.of(context);
        final species = PlantSpecies.forPlant(plant);

        return DiscardChangesGuard(
          hasChanges: !_saved && (_outcome != null || _soil != Soil.unknown),
          saving: _saving,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Check & water'),
              leading: const BackButton(),
            ),
            bottomNavigationBar: BottomAction(
              child: FilledButton(
                onPressed: _outcome == null || _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: PlantImage(
                          store: widget.store,
                          plant: plant,
                          height: 56,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plant.name, style: theme.textTheme.titleLarge),
                          Text(
                            _dueLabel(
                              relativeCheckLabel(
                                schedule.nextCheckAt,
                                DateTime.now(),
                              ),
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          pickNextCheck(context, widget.store, widget.plantId),
                      child: const Text('Edit next check'),
                    ),
                  ],
                ),
                if (species case final profile?
                    when profile.hasCareProfile) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.water_drop_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.careCue,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                const SectionHeader('What did you do?'),
                const SizedBox(height: 8),
                RadioGroup<WateringOutcome>(
                  groupValue: _outcome,
                  onChanged: (chosen) => setState(() => _outcome = chosen),
                  child: Column(
                    children: [
                      for (final value in WateringOutcome.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ChoiceCard(
                            value: value,
                            selected: _outcome == value,
                            icon: value == WateringOutcome.watered
                                ? Icons.water_drop
                                : Icons.visibility_outlined,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_outcome == WateringOutcome.checkedNotWatered) ...[
                  const SizedBox(height: 18),
                  const SectionHeader('How did the soil feel?'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<Soil>(
                      showSelectedIcon: false,
                      segments: [
                        for (final soil in Soil.values)
                          ButtonSegment(value: soil, label: Text(soil.label)),
                      ],
                      selected: {_soil},
                      onSelectionChanged: (selection) =>
                          setState(() => _soil = selection.first),
                    ),
                  ),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 16),
                  MessageBanner(error),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.value,
    required this.selected,
    required this.icon,
  });

  final WateringOutcome value;
  final bool selected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: RadioListTile<WateringOutcome>(
        value: value,
        controlAffinity: ListTileControlAffinity.trailing,
        secondary: Icon(icon, color: scheme.primary),
        title: Text(value.label),
      ),
    );
  }
}

/// "Due today", "Due in 5 days · Dec 1", or "Overdue · 2 days" as is.
String _dueLabel(String label) => label.startsWith('Overdue')
    ? label
    : 'Due ${label[0].toLowerCase()}${label.substring(1)}';
