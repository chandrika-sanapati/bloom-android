import 'package:bloom/domain/garden_store.dart';
import 'package:bloom/domain/models.dart';
import 'package:bloom/domain/plant_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final species = PlantSpecies.catalog.first;
  Plant plant(String id) => Plant(id: id, plantTypeId: species.id);
  GrowthPhoto photo(String id, String plantId, int day) => GrowthPhoto(
    id: id,
    plantId: plantId,
    takenAt: DateTime.utc(2026, 11, day),
    path: '/data/$id.jpg',
  );
  GardenStore store() => GardenStore(
    garden: Garden(plants: [plant('p'), plant('q')]),
    persist: (_) async {},
  );

  test('photos are added, listed newest first and shown in timeline', () async {
    final s = store();
    expect(await s.addGrowthPhoto(photo('a', 'p', 1)), isTrue);
    expect(await s.addGrowthPhoto(photo('b', 'p', 5)), isTrue);
    expect(await s.addGrowthPhoto(photo('b', 'p', 6)), isFalse);
    expect(await s.addGrowthPhoto(photo('x', 'missing', 6)), isFalse);
    expect(s.photosFor('p').map((p) => p.id), ['b', 'a']);
    final timeline = PlantActivity.forPlant(s.garden, 'p');
    expect(timeline.first.kind, PlantActivityKind.photo);
  });

  test('cover can be set, is cleared when its photo is removed', () async {
    final s = store();
    await s.addGrowthPhoto(photo('a', 'p', 1));
    expect(await s.setCoverPhoto('q', 'a'), isFalse);
    expect(await s.setCoverPhoto('p', 'a'), isTrue);
    expect(s.coverPhotoFor(s.plant('p')!)?.id, 'a');
    expect(await s.removeGrowthPhoto('a'), isTrue);
    expect(s.plant('p')!.coverPhotoId, isNull);
  });

  test('deleting a plant removes its photos only', () async {
    final s = store();
    await s.addGrowthPhoto(photo('a', 'p', 1));
    await s.addGrowthPhoto(photo('b', 'q', 1));
    await s.deletePlant('p');
    expect(s.garden.growthPhotos.map((p) => p.id), ['b']);
  });

  test('photos round-trip locally but never reach the cloud payload', () async {
    final s = store();
    await s.addGrowthPhoto(photo('a', 'p', 1));
    await s.setCoverPhoto('p', 'a');
    final local = Garden.fromJson(s.garden.toJson());
    expect(local.growthPhotos.single.path, '/data/a.jpg');
    expect(local.plants.first.coverPhotoId, 'a');
    final cloud = s.garden.toCloudJson();
    expect(cloud.containsKey('growthPhotos'), isFalse);
    expect(
      (cloud['plants'] as List).any(
        (p) => (p as Map).containsKey('coverPhotoId'),
      ),
      isFalse,
    );
  });
}
