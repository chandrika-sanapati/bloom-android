import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'widgets.dart';

/// Setup-time guidance with an optional "placed as suggested" checkbox.
class LightPlacementSection extends StatelessWidget {
  const LightPlacementSection({
    super.key,
    required this.guidance,
    required this.acknowledged,
    required this.onChanged,
    this.saving = false,
  });

  final PlantLightGuidance guidance;
  final bool acknowledged;
  final ValueChanged<bool>? onChanged;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Light & placement · optional'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guidance.requirement, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                LightPlacementScene(requirement: guidance.requirement),
                const SizedBox(height: 12),
                Text(guidance.placement, style: theme.textTheme.bodyMedium),
                const Divider(height: 24),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text("I've placed it as suggested"),
                  value: acknowledged,
                  onChanged: saving || onChanged == null
                      ? null
                      : (value) => onChanged!(value ?? false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Plant page panel: scene, profile advice and a plain-language confirmation.
class LightPlacementPanel extends StatelessWidget {
  const LightPlacementPanel({
    super.key,
    required this.guidance,
    required this.placement,
    required this.saving,
    required this.onAnswer,
    required this.onNotYet,
  });

  final PlantLightGuidance guidance;
  final LightPlacementAcknowledgment? placement;
  final bool saving;

  /// Called with true to confirm, false to clear a confirmation.
  final ValueChanged<bool> onAnswer;
  final VoidCallback onNotYet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = placement;
    final outdated =
        current != null && current.guidanceVersion != guidance.version;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LightPlacementScene(requirement: guidance.requirement),
        const SizedBox(height: 12),
        Text(
          guidance.placement,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (current != null && !outdated)
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'In a good spot',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        Text(
                          'Confirmed ${formatMonthDay(current.acknowledgedAt.toLocal())}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: saving ? null : () => onAnswer(false),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Text(
            outdated
                ? 'The advice was updated. Is it still in a spot like this?'
                : 'Is it in a spot like this?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: saving ? null : () => onAnswer(true),
                  child: Text(saving ? 'Saving…' : 'Yes, it is'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onNotYet,
                  child: const Text('Not yet'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Side view of a room: window, falling light, and the plant's best spot.
class LightPlacementScene extends StatelessWidget {
  const LightPlacementScene({super.key, required this.requirement});

  final String requirement;

  static const zoneLabels = [
    'By the window',
    'A few steps in',
    'Deeper in the room',
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
    final zone = zoneFor(requirement);
    final theme = Theme.of(context);
    return Semantics(
      image: true,
      label: 'Room illustration. Best spot: ${zoneLabels[zone].toLowerCase()}.',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomPaint(
              painter: _ScenePainter(
                zone: zone,
                scheme: theme.colorScheme,
                labelStyle: theme.textTheme.labelSmall!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.zone,
    required this.scheme,
    required this.labelStyle,
  });

  final int zone;
  final ColorScheme scheme;
  final TextStyle labelStyle;

  static const _sun = Color(0xFFF2B33D);
  static const _beam = Color(0xFFFAC775);
  static const _leaf = Color(0xFF4F8A2B);
  static const _pot = Color(0xFFC8775A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final floorY = h * 0.78;
    final wallW = w * 0.08;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = scheme.surfaceContainer,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, w, h - floorY),
      Paint()..color = scheme.surfaceContainerHighest,
    );

    // Light: a strong direct beam near the window, then a soft wash.
    final top = Offset(wallW, h * 0.18), bottom = Offset(wallW, h * 0.62);
    final zoneW = (w - wallW) / 3;
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(wallW + zoneW * 2.6, floorY)
        ..lineTo(wallW + zoneW * 0.9, floorY)
        ..lineTo(bottom.dx, bottom.dy)
        ..close(),
      Paint()..color = _beam.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(wallW + zoneW * 0.95, floorY)
        ..lineTo(wallW + zoneW * 0.2, floorY)
        ..lineTo(bottom.dx, bottom.dy)
        ..close(),
      Paint()..color = _beam.withValues(alpha: 0.55),
    );

    // Wall, window and sun.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, wallW, h),
      Paint()..color = scheme.outlineVariant,
    );
    final window = RRect.fromRectAndRadius(
      Rect.fromLTRB(wallW * 0.2, top.dy, wallW * 0.85, bottom.dy),
      const Radius.circular(3),
    );
    canvas.drawRRect(window, Paint()..color = const Color(0xFFB5D4F4));
    canvas.drawCircle(
      Offset(wallW * 0.55, h * 0.09),
      wallW * 0.3,
      Paint()..color = _sun,
    );

    // Floor line and zone labels.
    canvas.drawLine(
      Offset(wallW, floorY),
      Offset(w, floorY),
      Paint()
        ..color = scheme.outline
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 3; i++) {
      final selected = i == zone;
      final painter = TextPainter(
        text: TextSpan(
          text: LightPlacementScene.zoneLabels[i],
          style: labelStyle.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: zoneW - 6);
      painter.paint(
        canvas,
        Offset(
          wallW + zoneW * i + (zoneW - painter.width) / 2,
          floorY + (h - floorY - painter.height) / 2,
        ),
      );
    }

    // Recommended spot with the plant in it.
    final cx = wallW + zoneW * (zone + 0.5);
    final spot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, floorY - h * 0.2),
        width: zoneW * 0.78,
        height: h * 0.44,
      ),
      const Radius.circular(10),
    );
    final dash = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _dashed(canvas, Path()..addRRect(spot), dash);

    final s = math.min(zoneW, h) * 0.22;
    final potTop = floorY - s * 0.85;
    canvas.drawPath(
      Path()
        ..moveTo(cx - s * 0.5, potTop)
        ..lineTo(cx + s * 0.5, potTop)
        ..lineTo(cx + s * 0.38, floorY)
        ..lineTo(cx - s * 0.38, floorY)
        ..close(),
      Paint()..color = _pot,
    );
    final leaf = Paint()..color = _leaf;
    for (final (dx, dy, r) in [
      (-0.35, -0.55, 0.36),
      (0.35, -0.6, 0.38),
      (0.0, -1.0, 0.4),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + dx * s, potTop + dy * s),
          width: r * s * 1.4,
          height: r * s * 2,
        ),
        leaf,
      );
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.zone != zone || old.scheme != scheme;
}
