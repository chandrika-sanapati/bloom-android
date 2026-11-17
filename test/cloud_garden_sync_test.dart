import 'dart:convert';

import 'package:bloom/data/cloud_garden_sync.dart';
import 'package:bloom/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCloudBackend implements CloudGardenBackend {
  FakeCloudBackend({this.remote, this.revision = 0});

  Map<String, dynamic>? remote;
  int revision;
  bool fail = false;
  int reads = 0;
  int writes = 0;

  @override
  String? userId = 'user-1';

  @override
  Future<int?> readCollectionRevision(String userId) async {
    reads++;
    if (fail) throw StateError('offline');
    return remote == null ? null : revision;
  }

  @override
  Future<int?> syncCollection(
    String userId,
    int expectedRevision,
    Map<String, dynamic> garden,
  ) async {
    writes++;
    if (fail) throw StateError('offline');
    if (expectedRevision != revision) return null;
    remote = garden;
    revision++;
    return revision;
  }
}

Garden garden(String name) => Garden(
  plants: [Plant(id: 'p', plantTypeId: 'pothos', displayName: name)],
);

void main() {
  test('uploads an empty cloud garden and remembers its revision', () async {
    final backend = FakeCloudBackend();
    final sync = CloudGardenSync(backend: backend);

    expect(await sync.sync(garden('Local')), CloudSyncResult.synced);
    expect(backend.revision, 1);
    expect(sync.status.value, CloudSyncStatus.synced);
    expect(await sync.sync(garden('Local')), CloudSyncResult.synced);
  });

  test(
    'updates the cloud row after a local change at the known revision',
    () async {
      final backend = FakeCloudBackend();
      final sync = CloudGardenSync(backend: backend);

      await sync.sync(garden('First'));
      expect(await sync.sync(garden('Second')), CloudSyncResult.synced);
      expect(backend.revision, 2);
      expect(backend.remote?['plants'], isNotEmpty);
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
    expect(backend.remote?['plants'], isNotEmpty);
  });

  test(
    'retries a guarded overwrite when the remote changes during the write',
    () async {
      final backend = RetryingCloudBackend();
      final sync = CloudGardenSync(backend: backend);

      expect(await sync.sync(garden('Local')), CloudSyncResult.synced);
      expect(backend.revision, 7);
      expect(backend.remote?['plants'], isNotEmpty);
    },
  );

  test('failed sync keeps the local application state available', () async {
    final backend = FakeCloudBackend()..fail = true;
    final sync = CloudGardenSync(backend: backend);

    expect(await sync.sync(garden('Local')), CloudSyncResult.failed);
    expect(sync.status.value, CloudSyncStatus.failed);
    expect(sync.message.value, contains('still saved locally'));
  });

  test('signed-out sync does not call the backend', () async {
    final backend = FakeCloudBackend()..userId = null;
    final sync = CloudGardenSync(backend: backend);

    expect(await sync.sync(garden('Local')), CloudSyncResult.signedOut);
    expect(backend.reads, 0);
    expect(backend.writes, 0);
  });

  test('queued snapshots are uploaded in local-save order', () async {
    final backend = FakeCloudBackend();
    final sync = CloudGardenSync(backend: backend);

    final first = sync.sync(garden('First'));
    final second = sync.sync(garden('Second'));
    await Future.wait([first, second]);

    expect(jsonEncode(backend.remote), contains('Second'));
    expect(backend.revision, 2);
  });
}

class RetryingCloudBackend extends FakeCloudBackend {
  bool firstWrite = true;

  RetryingCloudBackend()
    : super(remote: garden('Remote').toJson(), revision: 4);

  @override
  Future<int?> syncCollection(
    String userId,
    int expectedRevision,
    Map<String, dynamic> garden,
  ) async {
    if (firstWrite) {
      firstWrite = false;
      revision = 6;
      return null;
    }
    return super.syncCollection(userId, expectedRevision, garden);
  }
}
