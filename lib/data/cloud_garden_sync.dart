import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

enum CloudSyncResult { unavailable, signedOut, synced, unchanged, failed }

enum CloudSyncStatus { unavailable, signedOut, syncing, synced, failed }

abstract interface class CloudGardenBackend {
  String? get userId;
  Future<int?> readCollectionRevision(String userId);
  Future<int?> syncCollection(
    String userId,
    int expectedRevision,
    Map<String, dynamic> garden,
  );
}

class SupabaseCloudGardenBackend implements CloudGardenBackend {
  SupabaseCloudGardenBackend(this.client);

  final SupabaseClient client;

  @override
  String? get userId => client.auth.currentUser?.id;

  @override
  Future<int?> readCollectionRevision(String userId) async =>
      (await client
              .from('plant_collections')
              .select('revision')
              .eq('user_id', userId)
              .maybeSingle())?['revision']
          as int?;

  @override
  Future<int?> syncCollection(
    String userId,
    int expectedRevision,
    Map<String, dynamic> garden,
  ) async {
    final response = await client.functions.invoke(
      'sync-plant-collection',
      body: {'expectedRevision': expectedRevision, 'payload': garden},
    );
    if (response.status == 409) return null;
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Collection sync failed.');
    }
    return (response.data as Map<String, dynamic>)['revision'] as int?;
  }
}

class CloudGardenSync {
  // Keep the injectable backend seam while retaining a private field.
  CloudGardenSync({CloudGardenBackend? backend})
    // ignore: prefer_initializing_formals
    : _backend = backend;

  final CloudGardenBackend? _backend;
  final status = ValueNotifier<CloudSyncStatus>(CloudSyncStatus.unavailable);
  final message = ValueNotifier<String?>(null);
  Future<void> _syncTail = Future.value();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  CloudGardenBackend? get _activeBackend {
    if (_backend != null) return _backend;
    final client = _client;
    return client == null ? null : SupabaseCloudGardenBackend(client);
  }

  bool get configured => _client != null;
  bool get signedIn => _client?.auth.currentSession != null;
  Future<CloudSyncResult> sync(Garden garden) {
    final work = _syncTail.then((_) => _sync(garden));
    _syncTail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<CloudSyncResult> _sync(Garden garden) async {
    final backend = _activeBackend;
    final userId = backend?.userId;
    if (backend == null) {
      return _set(CloudSyncResult.unavailable, 'Cloud sync is not configured.');
    }
    if (userId == null) {
      return _set(CloudSyncResult.signedOut, 'Sign in to sync your garden.');
    }

    status.value = CloudSyncStatus.syncing;
    message.value = null;
    final localPayload = garden.toCloudJson();
    try {
      var remoteRevision = await backend.readCollectionRevision(userId) ?? 0;
      for (var attempt = 0; attempt < 3; attempt++) {
        final revision = await backend.syncCollection(
          userId,
          remoteRevision,
          localPayload,
        );
        if (revision != null) {
          status.value = CloudSyncStatus.synced;
          return revision == remoteRevision
              ? CloudSyncResult.unchanged
              : CloudSyncResult.synced;
        }

        if (attempt < 2) {
          remoteRevision = await backend.readCollectionRevision(userId) ?? 0;
        }
      }

      return _set(
        CloudSyncResult.failed,
        'Cloud sync is busy. Your local garden is saved and will be retried.',
      );
    } catch (_) {
      status.value = CloudSyncStatus.failed;
      message.value = 'Cloud sync failed. Your garden is still saved locally.';
      return CloudSyncResult.failed;
    }
  }

  CloudSyncResult _set(CloudSyncResult result, String text) {
    status.value = switch (result) {
      CloudSyncResult.failed => CloudSyncStatus.failed,
      CloudSyncResult.signedOut => CloudSyncStatus.signedOut,
      _ => CloudSyncStatus.unavailable,
    };
    message.value = text;
    return result;
  }
}
