enum SoilCareAction {
  nutrientsAdded('Added nutrients'),
  mixRefreshed('Refreshed potting mix'),
  repotted('Repotted');

  const SoilCareAction(this.label);
  final String label;
}

/// One job can contain several explicitly selected actions, never duplicates.
class SoilCareEvent {
  SoilCareEvent({
    required this.id,
    required this.plantId,
    required this.occurredOn,
    required this.recordedAt,
    required Set<SoilCareAction> actions,
    this.product,
    this.notes,
    this.mixContainsFeed,
  }) : actions = Set.unmodifiable(actions);
  final String id;
  final String plantId;
  final DateTime occurredOn;
  final DateTime recordedAt;
  final Set<SoilCareAction> actions;
  final String? product;
  final String? notes;
  final bool? mixContainsFeed;

  String get title => SoilCareAction.values
      .where(actions.contains)
      .map((a) => a.label)
      .join(' · ');
  bool sameContentAs(SoilCareEvent other) =>
      plantId == other.plantId &&
      occurredOn == other.occurredOn &&
      title == other.title &&
      product == other.product &&
      notes == other.notes &&
      mixContainsFeed == other.mixContainsFeed;
  Map<String, dynamic> toJson() => {
    'id': id,
    'plantId': plantId,
    'occurredOn':
        '${occurredOn.year.toString().padLeft(4, '0')}-${occurredOn.month.toString().padLeft(2, '0')}-${occurredOn.day.toString().padLeft(2, '0')}',
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'actions': SoilCareAction.values
        .where(actions.contains)
        .map((a) => a.name)
        .toList(),
    if (product != null) 'product': product,
    if (notes != null) 'notes': notes,
    if (mixContainsFeed != null) 'mixContainsFeed': mixContainsFeed,
  };
  static SoilCareEvent? tryFromJson(Object? value) {
    try {
      if (value is! Map ||
          value['id'] is! String ||
          value['plantId'] is! String ||
          value['actions'] is! List) {
        return null;
      }
      final actions = (value['actions'] as List)
          .map((a) => SoilCareAction.values.byName(a as String))
          .toSet();
      final date = DateTime.parse(value['occurredOn'] as String);
      final event = SoilCareEvent(
        id: value['id'] as String,
        plantId: value['plantId'] as String,
        occurredOn: DateTime(date.year, date.month, date.day),
        recordedAt: DateTime.parse(value['recordedAt'] as String),
        actions: actions,
        product: value['product'] is String ? value['product'] as String : null,
        notes: value['notes'] is String ? value['notes'] as String : null,
        mixContainsFeed: value['mixContainsFeed'] is bool
            ? value['mixContainsFeed'] as bool
            : null,
      );
      if (event.id.isEmpty ||
          event.plantId.isEmpty ||
          actions.isEmpty ||
          event.toJson()['occurredOn'] != value['occurredOn']) {
        return null;
      }
      return event;
    } catch (_) {
      return null;
    }
  }
}
