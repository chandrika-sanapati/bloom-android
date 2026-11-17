import 'dart:io';

import 'package:bloom/data/garden_repository.dart';
import 'package:bloom/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bloom-repo-test');
    file = File('${dir.path}/garden.json');
  });
  tearDown(() => dir.delete(recursive: true));

  test('missing file loads an empty garden without a backup', () async {
    final repository = GardenRepository(file: file);
    expect((await repository.load()).plants, isEmpty);
    expect(repository.lastUnreadableBackup, isNull);
  });

  test('unreadable file is backed up before a save can overwrite it', () async {
    const corrupt = '{"plants": [ this is not json';
    await file.writeAsString(corrupt);
    final repository = GardenRepository(file: file);

    final garden = await repository.load();
    expect(garden.plants, isEmpty);
    final backup = repository.lastUnreadableBackup;
    expect(backup, isNotNull);
    expect(await File(backup!).readAsString(), corrupt);

    await repository.save(const Garden());
    expect(await File(backup).readAsString(), corrupt);
  });

  test('valid garden round-trips without a backup', () async {
    final repository = GardenRepository(file: file);
    final species = PlantSpecies.catalog.first;
    await repository.save(
      Garden(
        plants: [Plant(id: 'p', plantTypeId: species.id)],
      ),
    );
    final loaded = await repository.load();
    expect(loaded.plants.single.id, 'p');
    expect(repository.lastUnreadableBackup, isNull);
    expect(
      dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last),
      ['garden.json'],
    );
  });
}
