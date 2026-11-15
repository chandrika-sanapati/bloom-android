import 'package:timezone/timezone.dart' as tz;

/// A local calendar date and preferred wall clock, including DST gaps/folds.
DateTime reminderOnDay(
  DateTime day,
  int hour,
  int minute, {
  tz.Location? location,
}) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw ArgumentError('Invalid reminder time');
  }
  final midnight = location == null
      ? DateTime(day.year, day.month, day.day)
      : tz.TZDateTime(location, day.year, day.month, day.day);
  final start =
      midnight.millisecondsSinceEpoch - const Duration(hours: 6).inMilliseconds;
  // Scan in instant order: a repeated clock uses its first occurrence; a
  // missing clock uses the first valid minute after the gap.
  for (var offset = 0; offset <= 36 * 60; offset++) {
    final epoch = start + offset * Duration.millisecondsPerMinute;
    final local = location == null
        ? DateTime.fromMillisecondsSinceEpoch(epoch)
        : tz.TZDateTime.fromMillisecondsSinceEpoch(location, epoch);
    if (local.year == day.year &&
        local.month == day.month &&
        local.day == day.day &&
        local.hour * 60 + local.minute >= hour * 60 + minute) {
      return local;
    }
  }
  throw ArgumentError('The requested calendar day does not exist');
}

DateTime calendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
