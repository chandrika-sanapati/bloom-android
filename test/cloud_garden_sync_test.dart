import 'dart:convert';

import 'package:bloom/data/cloud_garden_sync.dart';
import 'package:bloom/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCloudBackend implements CloudGardenBackend {
  FakeCloudBackend({this.remote, this.revision = 0});

  Map<String, dynamic>? remote;
  int revision;
  bool fail = false;

  @override
  String? userId = 'user-1';

  @override
  Future<Map<String, dynamic>?> readGarden(String userId) async {
    if (fail) throw StateError('offline');
    return remote == null ? null : {'payload': remote, 'revision': revision};
  }

  @override
  Future<void> insertGarden(String userId, Map<String, dynamic> garden) async {
    if (fail) throw StateError('offline');
    remote = garden;
    revision = 1;
  }

  @override
  Future<int?> updateGarden(
    String userId,
    int expectedRevision,
    Map<String, dynamic> garden,
  ) async {
    if (fail) throw StateError('offline');
    if (expectedRevision != revision) return null;
    remote = garden;
    revision++;
    return revision;
  }
}

Garden garden(String name) => Garden(
  plants: [
    Plant(
      id: 'p',
      name: name,
      species: 'Epipremnum aureum',
      asset: 'assets/images/pothos.jpg',
    ),
  ],
);

void main() {
  test('uploads an empty cloud garden and remembers its revision', () async {
    final backend = FakeCloudBackend();
    final sync = CloudGardenSync(backend: backend);

    expect(await sync.sync(garden('Local')), CloudSyncResult.synced);
    expect(backend.revision, 1);
    expect(sync.status.value, CloudSyncStatus.synced);
    expect(await sync.sync(garden('Local')), CloudSyncResult.unchanged);
  });

  test(
    'updates the cloud row after a local change at the known revision',
    () async {
      final backend = FakeCloudBackend();
      final sync = CloudGardenSync(backend: backend);

      await sync.sync(garden('First'));
      expect(await sync.sync(garden('Second')), CloudSyncResult.synced);
      expect(backend.revision, 2);
      expect(jsonEncode(backend.remote), contains('Second'));
    },
  );

  test('overwrites a different remote garden with the local garden', () async {
    final backend = FakeCloudBackend(
      remote: garden('Remote').toJson(),
      revision: 4,
    );
    final sync = CloudGardenSync(backend: backend);

    expect(await sync.sync(garden('Local')), CloudSyncResult.synced);
    expect(sync.status.value, CloudSyncStatus.synced);
    expect(backend.revision, 5);
    expect(jsonEncode(backend.remote), contains('Local'));
  });

  test(
    'retries a guarded overwrite when the remote changes during the write',
    () async {
      final backend = RetryingCloudBackend();
      final sync = CloudGardenSync(backend: backend);

      expect(await sync.sync(garden('Local')), CloudSyncResult.synced);
      expect(backend.revision, 7);
      expect(jsonEncode(backend.remote), contains('Local'));
    },
  );

  test('failed sync keeps the local application state available', () async {
    final backend = FakeCloudBackend()..fail = true;
    final sync = CloudGardenSync(backend: backend);

    expect(await sync.sync(garden('Local')), CloudSyncResult.failed);
    expect(sync.status.value, CloudSyncStatus.failed);
    expect(sync.message.value, contains('still saved locally'));
  });
}

class RetryingCloudBackend extends FakeCloudBackend {
  bool firstWrite = true;

  RetryingCloudBackend()
    : super(remote: garden('Remote').toJson(), revision: 4);

  @override
  Future<int?> updateGarden(
    String userId,
    int expectedRevision,
    Map<String, dynamic> garden,
  ) async {
    if (firstWrite) {
      firstWrite = false;
      revision = 6;
      return null;
    }
    return super.updateGarden(userId, expectedRevision, garden);
  }
}
