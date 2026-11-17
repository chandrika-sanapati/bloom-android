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
                const SizedBox(height: 12),
                LightPlacementDiagram(requirement: guidance.requirement),
              ],
            ),
          ),
          children: [
            _guidanceBody(context, showRequirement: false, showDiagram: false),
          ],
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

  Widget _guidanceBody(
    BuildContext context, {
    bool showRequirement = true,
    bool showDiagram = true,
  }) {
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
          if (showDiagram) ...[
            LightPlacementDiagram(requirement: guidance.requirement),
            const SizedBox(height: 12),
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

/// Simple picture of where the plant should sit relative to a window.
class LightPlacementDiagram extends StatelessWidget {
  const LightPlacementDiagram({super.key, required this.requirement});

  final String requirement;

  static const _zones = [
    'At the window',
    'Near, out of direct sun',
    'Further into the room',
  ];

  /// Maps the profile's light requirement to a distance from the window.
  static int zoneFor(String requirement) {
    final text = requirement.toLowerCase();
    if (text.contains('medium') || text.contains('low')) return 2;
    if (text.contains('indirect')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = zoneFor(requirement);
    return Semantics(
      label: 'Best spot: ${_zones[selected].toLowerCase()}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 44,
                color: scheme.tertiaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.wb_sunny, color: scheme.onTertiaryContainer),
                    Icon(Icons.window, color: scheme.onTertiaryContainer),
                  ],
                ),
              ),
              for (var i = 0; i < _zones.length; i++)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? scheme.primaryContainer
                          : Color.lerp(
                              scheme.surfaceContainerHigh,
                              scheme.surfaceContainerLowest,
                              i / (_zones.length - 1),
                            ),
                      border: Border(
                        left: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.local_florist,
                          size: i == selected ? 32 : 22,
                          color: i == selected
                              ? scheme.onPrimaryContainer
                              : scheme.outlineVariant,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _zones[i],
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            color: i == selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                            fontWeight: i == selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
