import 'models.dart';
import 'soil_care.dart';

enum PlantActivityKind { watered, checked, placement, soilCare }

class PlantActivity {
  const PlantActivity({
    required this.id,
    required this.date,
    required this.kind,
    this.watering,
    this.soilCare,
  });
  final String id;
  final DateTime date;
  final PlantActivityKind kind;
  final WateringRecord? watering;
  final SoilCareEvent? soilCare;

  static List<PlantActivity> forPlant(Garden garden, String plantId) {
    final plants = garden.plants.where((p) => p.id == plantId);
    if (plants.isEmpty) return const [];
    final placement = plants.first.lightPlacement;
    final entries = <PlantActivity>[
      for (final record in garden.records.where((r) => r.plantId == plantId))
        PlantActivity(
          id: 'watering:${record.id}',
          date: record.recordedAt,
          kind: record.outcome == WateringOutcome.watered
              ? PlantActivityKind.watered
              : PlantActivityKind.checked,
          watering: record,
        ),
      if (placement != null)
        PlantActivity(
          id: 'placement:$plantId',
          date: placement.acknowledgedAt,
          kind: PlantActivityKind.placement,
        ),
      for (final event in garden.soilCare.where((e) => e.plantId == plantId))
        PlantActivity(
          id: 'soil:${event.id}',
          date: event.occurredOn,
          kind: PlantActivityKind.soilCare,
          soilCare: event,
        ),
    ];
    entries.sort((a, b) {
      final ad = a.date.toLocal();
      final bd = b.date.toLocal();
      final date = DateTime.utc(
        bd.year,
        bd.month,
        bd.day,
      ).compareTo(DateTime.utc(ad.year, ad.month, ad.day));
      if (date != 0) return date;
      // Date-only soil work has no invented clock time; use recording time for
      // a stable within-day order, while displaying only its care date.
      final order = (b.soilCare?.recordedAt ?? b.date).compareTo(
        a.soilCare?.recordedAt ?? a.date,
      );
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return entries;
  }
}
