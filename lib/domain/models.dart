import 'dart:math';
import 'soil_care.dart';

enum Soil {
  dry('Dry'),
  damp('Damp'),
  unknown('Not sure');

  const Soil(this.label);
  final String label;
}

enum WateringOutcome {
  watered('Watered'),
  checkedNotWatered('Checked — not watered');

  const WateringOutcome(this.label);
  final String label;
}

enum CareTaskTiming {
  overdue('Overdue'),
  today('Today'),
  upcoming('Upcoming');

  const CareTaskTiming(this.label);
  final String label;

  static CareTaskTiming classify(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (date.isBefore(current)) return CareTaskTiming.overdue;
    return _isSameDay(date, current)
        ? CareTaskTiming.today
        : CareTaskTiming.upcoming;
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class Plant {
  const Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.asset,
    this.lightPlacement,
  });

  final String id;
  final String name;
  final String species;
  final String asset;
  final LightPlacementAcknowledgment? lightPlacement;

  Plant copyWith({
    String? name,
    String? species,
    String? asset,
    LightPlacementAcknowledgment? lightPlacement,
    bool clearLightPlacement = false,
  }) => Plant(
    id: id,
    name: name ?? this.name,
    species: species ?? this.species,
    asset: asset ?? this.asset,
    lightPlacement: clearLightPlacement
        ? null
        : lightPlacement ?? this.lightPlacement,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    'asset': asset,
    if (lightPlacement != null) 'lightPlacement': lightPlacement!.toJson(),
  };

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
    id: json['id'] as String,
    name: json['name'] as String,
    species: json['species'] as String,
    asset: json['asset'] as String,
    lightPlacement: LightPlacementAcknowledgment.tryFromJson(
      json['lightPlacement'],
    ),
  );
}

/// A user's acknowledgment of acting on a particular version of light guidance.
/// This is independent of measured light and watering history.
class LightPlacementAcknowledgment {
  const LightPlacementAcknowledgment({
    required this.acknowledgedAt,
    required this.guidanceVersion,
  });

  final DateTime acknowledgedAt;
  final int guidanceVersion;

  Map<String, dynamic> toJson() => {
    'acknowledgedAt': acknowledgedAt.toIso8601String(),
    'guidanceVersion': guidanceVersion,
  };

  static LightPlacementAcknowledgment? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final timestamp = value['acknowledgedAt'];
    final version = value['guidanceVersion'];
    if (timestamp is! String || version is! int || version < 1) return null;
    final date = DateTime.tryParse(timestamp);
    if (date == null) return null;
    return LightPlacementAcknowledgment(
      acknowledgedAt: date,
      guidanceVersion: version,
    );
  }
}

class WateringRecord {
  const WateringRecord({
    required this.id,
    required this.plantId,
    required this.scheduledFor,
    required this.recordedAt,
    required this.outcome,
    required this.soil,
  });

  final String id;
  final String plantId;
  final DateTime scheduledFor;
  final DateTime recordedAt;
  final WateringOutcome outcome;
  final Soil soil;

  Map<String, dynamic> toJson() => {
    'id': id,
    'plantId': plantId,
    'scheduledFor': scheduledFor.toIso8601String(),
    'recordedAt': recordedAt.toIso8601String(),
    'outcome': outcome.name,
    'soil': soil.name,
  };

  factory WateringRecord.fromJson(Map<String, dynamic> json) => WateringRecord(
    id: json['id'] as String,
    plantId: json['plantId'] as String,
    scheduledFor: DateTime.parse(json['scheduledFor'] as String),
    recordedAt: DateTime.parse(json['recordedAt'] as String),
    outcome: WateringOutcome.values.byName(json['outcome'] as String),
    soil: Soil.values.byName(json['soil'] as String),
  );
}

enum CheckTimeSource { preference, custom, legacy }

class WateringSchedule {
  const WateringSchedule({
    required this.plantId,
    required this.intervalDays,
    required this.nextCheckAt,
    required this.createdAt,
    required this.updatedAt,
    this.timeSource = CheckTimeSource.legacy,
  });

  final String plantId;
  final int intervalDays;
  final DateTime nextCheckAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CheckTimeSource timeSource;

  WateringSchedule copyWith({
    DateTime? nextCheckAt,
    DateTime? updatedAt,
    CheckTimeSource? timeSource,
  }) => WateringSchedule(
    plantId: plantId,
    intervalDays: intervalDays,
    nextCheckAt: nextCheckAt ?? this.nextCheckAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    timeSource: timeSource ?? this.timeSource,
  );

  Map<String, dynamic> toJson() => {
    'plantId': plantId,
    'intervalDays': intervalDays,
    'nextCheckAt': nextCheckAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'timeSource': timeSource.name,
  };

  factory WateringSchedule.fromJson(Map<String, dynamic> json) =>
      WateringSchedule(
        plantId: json['plantId'] as String,
        intervalDays: json['intervalDays'] as int,
        nextCheckAt: DateTime.parse(json['nextCheckAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        timeSource: CheckTimeSource.values.firstWhere(
          (value) => value.name == json['timeSource'],
          orElse: () => CheckTimeSource.legacy,
        ),
      );
}

class AppPreferences {
  const AppPreferences({
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.taskNotifications = false,
  });

  final int reminderHour;
  final int reminderMinute;
  final bool taskNotifications;

  AppPreferences copyWith({
    bool? taskNotifications,
    int? reminderHour,
    int? reminderMinute,
  }) => AppPreferences(
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    taskNotifications: taskNotifications ?? this.taskNotifications,
  );

  Map<String, dynamic> toJson() => {
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'taskNotifications': taskNotifications,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    reminderHour: _validTimePart(json['reminderHour'], 23, 9),
    reminderMinute: _validTimePart(json['reminderMinute'], 59, 0),
    taskNotifications: json['taskNotifications'] as bool? ?? false,
  );
}

int _validTimePart(Object? value, int max, int fallback) =>
    value is int && value >= 0 && value <= max ? value : fallback;

class Garden {
  const Garden({
    this.plants = const [],
    this.schedules = const [],
    this.records = const [],
    this.soilCare = const [],
    this.preferences = const AppPreferences(),
  });

  final List<Plant> plants;
  final List<WateringSchedule> schedules;
  final List<WateringRecord> records;
  final List<SoilCareEvent> soilCare;
  final AppPreferences preferences;

  Garden copyWith({
    List<Plant>? plants,
    List<WateringSchedule>? schedules,
    List<WateringRecord>? records,
    List<SoilCareEvent>? soilCare,
    AppPreferences? preferences,
  }) => Garden(
    plants: plants ?? this.plants,
    schedules: schedules ?? this.schedules,
    records: records ?? this.records,
    soilCare: soilCare ?? this.soilCare,
    preferences: preferences ?? this.preferences,
  );

  Map<String, dynamic> toJson() => {
    'plants': plants.map((p) => p.toJson()).toList(),
    'schedules': schedules.map((s) => s.toJson()).toList(),
    'records': records.map((r) => r.toJson()).toList(),
    'soilCare': soilCare.map((r) => r.toJson()).toList(),
    'preferences': preferences.toJson(),
  };

  factory Garden.fromJson(Map<String, dynamic> json) => Garden(
    plants: (json['plants'] as List? ?? [])
        .map((p) => Plant.fromJson(p as Map<String, dynamic>))
        .toList(),
    schedules: (json['schedules'] as List? ?? [])
        .map((s) => WateringSchedule.fromJson(s as Map<String, dynamic>))
        .toList(),
    records: (json['records'] as List? ?? [])
        .map((r) => WateringRecord.fromJson(r as Map<String, dynamic>))
        .toList(),
    soilCare: json['soilCare'] is List
        ? (json['soilCare'] as List)
              .map(SoilCareEvent.tryFromJson)
              .whereType<SoilCareEvent>()
              .toList()
        : const [],
    preferences: json['preferences'] == null
        ? const AppPreferences()
        : AppPreferences.fromJson(json['preferences'] as Map<String, dynamic>),
  );
}

/// Reviewed species content shared by setup and plant detail.
class PlantLightGuidance {
  const PlantLightGuidance({
    required this.requirement,
    required this.placement,
    required this.sourceUrl,
    this.version = 1,
  });

  final String requirement;
  final String placement;
  final String sourceUrl;
  final int version;
}

/// Supported species and care profiles for the Android catalog.
class PlantSpecies {
  const PlantSpecies({
    required this.name,
    required this.scientific,
    required this.asset,
    required this.minDays,
    required this.maxDays,
    required this.startingIntervalDays,
    required this.careCue,
    required this.light,
  });

  final String name;
  final String scientific;
  final String asset;
  final int minDays;
  final int maxDays;
  final int startingIntervalDays;
  final String careCue;
  final PlantLightGuidance light;

  static const catalog = [
    PlantSpecies(
      name: 'Snake Plant',
      scientific: 'Dracaena trifasciata',
      asset: 'assets/images/snake.png',
      minDays: 14,
      maxDays: 30,
      startingIntervalDays: 21,
      careCue: 'Let the growing medium dry substantially before watering.',
      light: PlantLightGuidance(
        requirement: 'Bright daylight',
        placement:
            'Place near a window with good daylight. Some direct sun is '
            'fine; introduce stronger sun gradually.',
        sourceUrl: 'https://plants.ces.ncsu.edu/plants/dracaena-trifasciata/',
      ),
    ),
    PlantSpecies(
      name: 'Monstera',
      scientific: 'Monstera deliciosa',
      asset: 'assets/images/monstera.png',
      minDays: 7,
      maxDays: 14,
      startingIntervalDays: 10,
      careCue: 'Check the top 1–2 inches of soil and avoid waterlogging.',
      light: PlantLightGuidance(
        requirement: 'Indirect daylight',
        placement:
            'Place near a bright window, away from strong sun shining '
            'directly on the leaves.',
        sourceUrl: 'https://plants.ces.ncsu.edu/plants/monstera-deliciosa/',
      ),
    ),
    PlantSpecies(
      name: 'Rubber Plant',
      scientific: 'Ficus elastica',
      asset: 'assets/images/rubber.png',
      minDays: 7,
      maxDays: 21,
      startingIntervalDays: 14,
      careCue: 'Use a free-draining medium and check before watering.',
      light: PlantLightGuidance(
        requirement: 'Bright, indirect light',
        placement:
            'Place near a bright window, sheltered from strong afternoon '
            'sun. Daylight should reach the plant without harsh sun on its leaves.',
        sourceUrl: 'https://plants.ces.ncsu.edu/plants/ficus-elastica/',
      ),
    ),
    PlantSpecies(
      name: 'Pothos',
      scientific: 'Epipremnum aureum',
      asset: 'assets/images/pothos.jpg',
      minDays: 7,
      maxDays: 21,
      startingIntervalDays: 14,
      careCue:
          'Allow the soil to dry between checks; avoid keeping it constantly wet.',
      light: PlantLightGuidance(
        requirement: 'Bright, indirect light',
        placement:
            'Choose a bright spot out of strong direct sun. It tolerates '
            'lower light, but grows best with plenty of indirect daylight.',
        sourceUrl: 'https://plants.ces.ncsu.edu/plants/epipremnum-aureum/',
      ),
    ),
  ];

  static PlantSpecies? forPlant(Plant plant) {
    final scientific = plant.species.trim().toLowerCase();
    for (final species in catalog) {
      if (species.scientific.toLowerCase() == scientific) return species;
    }
    for (final species in catalog) {
      if (species.name.toLowerCase() == plant.name.trim().toLowerCase()) {
        return species;
      }
    }
    return null;
  }
}

/// Dry-soil follow-up window used by the current watering baseline.
class WateringFollowUp {
  static const defaultDays = 3;
  static const allowedDays = [2, 3, 4, 5];
}

final _random = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
