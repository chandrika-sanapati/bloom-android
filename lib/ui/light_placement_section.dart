import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Shared guidance: visible during setup, progressively disclosed on detail.
class LightPlacementSection extends StatelessWidget {
  const LightPlacementSection({
    super.key,
    required this.guidance,
    required this.acknowledged,
    required this.onChanged,
    this.saving = false,
    this.earlierGuidance = false,
    this.compact = false,
  });

  final PlantLightGuidance guidance;
  final bool acknowledged;
  final ValueChanged<bool>? onChanged;
  final bool saving;
  final bool earlierGuidance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      final state = saving
          ? 'Saving…'
          : earlierGuidance
          ? 'Placement recorded for earlier advice'
          : acknowledged
          ? "You've placed it as suggested"
          : 'Not recorded · Optional';
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text('Light & placement'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guidance.requirement),
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: saving,
                  child: Text(state, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          children: [_guidanceBody(context, showRequirement: false)],
        ),
      );
    }
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
        Card(margin: EdgeInsets.zero, child: _guidanceBody(context)),
      ],
    );
  }

  Widget _guidanceBody(BuildContext context, {bool showRequirement = true}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showRequirement) ...[
            Text(guidance.requirement, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
          ],
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
          if (saving && !compact)
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
    );
  }
}
