import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../domain/watering_notification.dart';

RouteSettings wateringCheckSettings(WateringSchedule schedule) => RouteSettings(
  name: '/watering-check',
  arguments: WateringNotificationTarget.encode(schedule, ''),
);
