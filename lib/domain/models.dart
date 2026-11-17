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
    this.plantTypeId,
    this.displayName,
    @Deprecated('Use plantTypeId and displayName.') String? name,
    @Deprecated('Use plantTypeId.') String? species,
    @Deprecated('Use the data-driven profile catalog.') String? asset,
    String? legacyName,
    String? legacySpecies,
    String? legacyAsset,
    this.lightPlacement,
  }) : legacyName = legacyName ?? name,
       legacySpecies = legacySpecies ?? species,
       legacyAsset = legacyAsset ?? asset;

  final String id;
  final String? plantTypeId;
  final String? displayName;
  @Deprecated('Use plantTypeId and displayName.')
  final String? legacyName;
  @Deprecated('Use plantTypeId and the data-driven profile catalog.')
  final String? legacySpecies;
  @Deprecated('Use the data-driven profile catalog.')
  final String? legacyAsset;
  final LightPlacementAcknowledgment? lightPlacement;

  Plant canonicalized() {
    final profile = PlantSpecies.forPlant(this);
    if (profile == null) return this;
    return Plant(
      id: id,
      plantTypeId: profile.id,
      displayName: displayName,
      lightPlacement: lightPlacement,
    );
  }

  String get name =>
      displayName ?? PlantSpecies.forPlant(this)?.name ?? legacyName ?? 'Plant';
  String get species =>
      PlantSpecies.forPlant(this)?.scientific ??
      legacySpecies ??
      'Unknown species';
  String get asset =>
      PlantSpecies.forPlant(this)?.asset ??
      legacyAsset ??
      'assets/images/area-whole.png';

  Plant copyWith({
    String? plantTypeId,
    String? displayName,
    @Deprecated('Use displayName.') String? name,
    @Deprecated('Use plantTypeId.') String? species,
    @Deprecated('Use the data-driven profile catalog.') String? asset,
    LightPlacementAcknowledgment? lightPlacement,
    bool clearLightPlacement = false,
    bool clearDisplayName = false,
  }) => Plant(
    id: id,
    plantTypeId: plantTypeId ?? this.plantTypeId,
    displayName: clearDisplayName
        ? null
        : displayName ?? name ?? this.displayName,
    legacyName: legacyName ?? name,
    legacySpecies: legacySpecies ?? species,
    legacyAsset: legacyAsset ?? asset,
    lightPlacement: clearLightPlacement
        ? null
        : lightPlacement ?? this.lightPlacement,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plantTypeId': plantTypeId,
    if (displayName != null) 'displayName': displayName,
    if (lightPlacement != null) 'lightPlacement': lightPlacement!.toJson(),
  };

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
    id: json['id'] as String,
    plantTypeId: json['plantTypeId'] as String?,
    displayName: json['displayName'] as String?,
    legacyName: json['name'] as String?,
    legacySpecies: json['species'] as String?,
    legacyAsset: json['asset'] as String?,
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

  factory PlantLightGuidance.fromJson(Map<String, dynamic> json) =>
      PlantLightGuidance(
        requirement: json['requirement'] as String,
        placement: json['placement'] as String,
        sourceUrl: json['sourceUrl'] as String,
        version: json['version'] as int? ?? 1,
      );
}

/// Runtime profile data loaded from the managed catalog asset/cache.
class PlantSpecies {
  const PlantSpecies({
    required this.id,
    required this.name,
    required this.scientific,
    required this.asset,
    required this.minDays,
    required this.maxDays,
    required this.startingIntervalDays,
    required this.careCue,
    required this.light,
    this.aliases = const [],
    this.reviewStatus = 'reviewed',
  });

  final String id;
  final String name;
  final String scientific;
  final String asset;
  final int minDays;
  final int maxDays;
  final int startingIntervalDays;
  final String careCue;
  final PlantLightGuidance light;
  final List<String> aliases;
  final String reviewStatus;

  bool get hasCareProfile => reviewStatus == 'reviewed';

  static List<PlantSpecies> _catalog = const [];
  static void setCatalog(List<PlantSpecies> profiles) => _catalog = profiles;

  factory PlantSpecies.fromJson(Map<String, dynamic> json) => PlantSpecies(
    id: json['id'] as String,
    name: json['name'] as String,
    scientific: json['scientificName'] as String,
    aliases: (json['aliases'] as List? ?? const []).cast<String>(),
    asset: json['asset'] as String,
    minDays: json['minDays'] as int,
    maxDays: json['maxDays'] as int,
    startingIntervalDays: json['startingIntervalDays'] as int,
    careCue: json['careCue'] as String,
    light: PlantLightGuidance.fromJson(json['light'] as Map<String, dynamic>),
    reviewStatus: json['reviewStatus'] as String? ?? 'reviewed',
  );

  static List<PlantSpecies> get catalog => _catalog
      .where((profile) => profile.hasCareProfile)
      .toList(growable: false);

  static PlantSpecies? forPlant(Plant plant) {
    final requested = plant.plantTypeId?.trim();
    for (final profile in _catalog) {
      if (requested?.isNotEmpty == true && profile.id == requested) {
        return profile;
      }
    }
    final values = [
      plant.displayName ?? plant.legacyName,
      plant.legacySpecies,
    ].whereType<String>().map(_normalize).where((value) => value.isNotEmpty);
    return _find(values);
  }

  static PlantSpecies? forScientificName(String scientific) =>
      _find([_normalize(scientific), _scientificBase(scientific)]);

  static PlantSpecies? forCandidate({
    required String scientificName,
    List<String> commonNames = const [],
  }) => _find([
    _normalize(scientificName),
    _scientificBase(scientificName),
    ...commonNames.map(_normalize),
  ]);

  static PlantSpecies? _find(Iterable<String> values) {
    for (final value in values) {
      for (final profile in _catalog) {
        if (_normalize(profile.name) == value ||
            _normalize(profile.scientific) == value ||
            profile.aliases.any((alias) => _normalize(alias) == value)) {
          return profile;
        }
      }
    }
    return null;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String _scientificBase(String value) {
    final words = _normalize(value).split(' ');
    return words.length < 2 ? _normalize(value) : words.take(2).join(' ');
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
