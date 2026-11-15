import 'package:flutter/material.dart';

import '../domain/models.dart';

/// The same short suggestion and optional input in setup and plant detail.
class LightPlacementSection extends StatelessWidget {
  const LightPlacementSection({
    super.key,
    required this.guidance,
    required this.acknowledged,
    required this.onChanged,
    this.saving = false,
    this.earlierGuidance = false,
  });

  final PlantLightGuidance guidance;
  final bool acknowledged;
  final ValueChanged<bool>? onChanged;
  final bool saving;
  final bool earlierGuidance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Light & placement', style: theme.textTheme.titleSmall),
            Text(
              'Optional',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guidance.requirement, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(guidance.placement, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                const Divider(),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text("I've placed it as suggested"),
                  value: acknowledged,
                  onChanged: saving || onChanged == null
                      ? null
                      : (value) => onChanged!(value ?? false),
                ),
                if (saving)
                  Semantics(
                    liveRegion: true,
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Saving…'),
                    ),
                  ),
                if (earlierGuidance)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Your acknowledgment is for earlier guidance. You can '
                      'uncheck and confirm again after following this suggestion.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
