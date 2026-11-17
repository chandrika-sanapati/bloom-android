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
          : CircleAvatar(
              radius: 20,
              backgroundColor: highlighted
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                icon,
                size: 20,
                color: highlighted
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
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

int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.year, from.month, from.day);
  final b = DateTime(to.year, to.month, to.day);
  return b.difference(a).inHours ~/ 24;
}

/// "Today", "Tomorrow", "In 5 days · Dec 1", "Overdue · 2 days".
String relativeCheckLabel(DateTime when, DateTime now) {
  final local = when.toLocal();
  final days = calendarDaysBetween(now, local);
  if (local.isBefore(now) && days < 0) {
    return days == -1 ? 'Overdue · 1 day' : 'Overdue · ${-days} days';
  }
  if (days <= 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'In $days days · ${formatMonthDay(local)}';
}

/// "today", "yesterday", "9 days ago".
String relativeAgo(DateTime when, DateTime now) {
  final days = calendarDaysBetween(when.toLocal(), now);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}

/// Section title used on every screen; optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

/// Inline status message: tinted, with an icon, announced to screen readers.
class MessageBanner extends StatelessWidget {
  const MessageBanner(this.message, {super.key, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 20,
              color: fg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one primary action of a screen, pinned above the system bar.
class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
