import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/garden_store.dart';
import '../domain/models.dart';
import '../domain/plant_activity.dart';

final _monthDay = DateFormat.MMMd();
final _dateTime = DateFormat.yMMMd().add_jm();
final _date = DateFormat.yMMMd();

String formatMonthDay(DateTime date) => _monthDay.format(date);
String formatDateTime(DateTime date) => _dateTime.format(date);
String formatDate(DateTime date) => _date.format(date);

class BloomTitle extends StatelessWidget {
  const BloomTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/images/bloom_logo.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Bloom',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class PlantCard extends StatelessWidget {
  const PlantCard({
    super.key,
    required this.plant,
    required this.schedule,
    required this.onTap,
    this.store,
    this.onLongPress,
    this.selected,
  });

  final Plant plant;
  final WateringSchedule? schedule;
  final VoidCallback onTap;
  final GardenStore? store;
  final VoidCallback? onLongPress;

  /// Null outside selection mode; otherwise whether this card is selected.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status(theme);

    final isSelected = selected == true;
    final card = SizedBox(
      width: 150,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: theme.colorScheme.primary, width: 3)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              store == null
                  ? Image.asset(
                      plant.asset,
                      height: 126,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : PlantImage(store: store!, plant: plant, height: 126),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    status,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return card;
    return Semantics(
      selected: isSelected,
      child: Stack(
        children: [
          card,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: Icon(
                isSelected ? Icons.check : Icons.circle_outlined,
                size: 22,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(ThemeData theme) {
    final current = schedule;
    if (current == null) {
      return Text(
        'Schedule unavailable',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final timing = CareTaskTiming.classify(current.nextCheckAt);
    final overdue = timing == CareTaskTiming.overdue;
    final text = timing == CareTaskTiming.upcoming
        ? formatMonthDay(current.nextCheckAt)
        : timing.label;
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: overdue
            ? Colors.orange.shade800
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.plant,
    required this.schedule,
    required this.timing,
    required this.onTap,
  });

  final Plant plant;
  final WateringSchedule schedule;
  final CareTaskTiming timing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = timing == CareTaskTiming.overdue;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          overdue ? Icons.error_outline : Icons.water_drop,
          color: overdue ? Colors.orange.shade800 : theme.colorScheme.primary,
        ),
        title: const Text('Check & water'),
        subtitle: Text(plant.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMonthDay(schedule.nextCheckAt),
              style: theme.textTheme.labelLarge?.copyWith(
                color: overdue
                    ? Colors.orange.shade800
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.plant,
    required this.entry,
    this.showPlantName = true,
    this.onTap,
  });

  final Plant plant;
  final PlantActivity entry;
  final bool showPlantName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soil = entry.watering?.soil;
    final (title, icon, highlighted) = switch (entry.kind) {
      PlantActivityKind.watered => (
        entry.watering!.outcome.label,
        Icons.water_drop,
        true,
      ),
      PlantActivityKind.checked => (
        entry.watering!.outcome.label,
        Icons.visibility_outlined,
        false,
      ),
      PlantActivityKind.placement => (
        'Light placement confirmed',
        Icons.wb_sunny_outlined,
        false,
      ),
      PlantActivityKind.soilCare => (
        entry.soilCare!.title,
        Icons.eco_outlined,
        true,
      ),
      PlantActivityKind.photo => (
        'Growth photo',
        Icons.photo_camera_outlined,
        true,
      ),
    };
    final showSoil = soil != null && soil != Soil.unknown;
    final lines = [
      if (showPlantName) plant.name,
      if (showSoil) 'Soil: ${soil.label}',
    ];
    final photo = entry.photo;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
      leading: photo != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(photo.path),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                cacheWidth: 120,
                errorBuilder: (_, _, _) => Icon(icon),
              ),
            )
          : Icon(
              icon,
              color: highlighted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
      title: Text(title),
      subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
      isThreeLine: lines.length > 1,
      trailing: Text(
        formatMonthDay(entry.date.toLocal()),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class EmptyActivityCard extends StatelessWidget {
  const EmptyActivityCard({
    super.key,
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks a date and time for the next check and saves it, rejecting past times.
Future<void> pickNextCheck(
  BuildContext context,
  GardenStore store,
  String plantId,
) async {
  final schedule = store.scheduleFor(plantId);
  if (schedule == null) return;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final current = schedule.nextCheckAt.isBefore(now)
      ? now
      : schedule.nextCheckAt;

  final date = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: today,
    lastDate: today.add(const Duration(days: 365 * 3)),
  );
  if (date == null || !context.mounted) return;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null || !context.mounted) return;

  final chosen = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  final saved = await store.editNextCheck(plantId, chosen);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Choose a time in the future.')),
    );
  }
}

/// The plant's chosen growth photo, or its catalog image.
class PlantImage extends StatelessWidget {
  const PlantImage({
    super.key,
    required this.store,
    required this.plant,
    required this.height,
  });

  final GardenStore store;
  final Plant plant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      plant.asset,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
    final cover = store.coverPhotoFor(plant);
    if (cover == null) return fallback;
    return Image.file(
      File(cover.path),
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheHeight: (height * 3).round(),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
