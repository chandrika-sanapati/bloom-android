import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

enum CloudSyncResult { unavailable, signedOut, synced, unchanged, failed }

enum CloudSyncStatus { unavailable, signedOut, syncing, synced, failed }

abstract interface class CloudGardenBackend {
  String? get userId;
  Future<Map<String, dynamic>?> readGarden(String userId);
  Future<void> insertGarden(String userId, Map<String, dynamic> garden);
  Future<int?> updateGarden(
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
  Future<Map<String, dynamic>?> readGarden(String userId) async => await client
      .from('gardens')
      .select('payload, revision')
      .eq('user_id', userId)
      .maybeSingle();

  @override
  Future<void> insertGarden(String userId, Map<String, dynamic> garden) async {
    await client.from('gardens').insert({
      'user_id': userId,
      'schema_version': 1,
      'payload': garden,
      'revision': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<int?> updateGarden(
    String userId,
    int expectedRevision,
    Map<String, dynamic> garden,
  ) async {
    final updated = await client
        .from('gardens')
        .update({
          'payload': garden,
          'schema_version': 1,
          'revision': expectedRevision + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('revision', expectedRevision)
        .select('revision')
        .maybeSingle();
    return (updated?['revision'] as num?)?.toInt();
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
    final localPayload = garden.toJson();
    final localJson = jsonEncode(localPayload);
    try {
      var remote = await backend.readGarden(userId);

      if (remote == null) {
        await backend.insertGarden(userId, localPayload);
        status.value = CloudSyncStatus.synced;
        return CloudSyncResult.synced;
      }

      for (var attempt = 0; attempt < 3; attempt++) {
        final currentRemote = remote;
        if (currentRemote == null) break;
        final remoteRevision =
            (currentRemote['revision'] as num?)?.toInt() ?? 0;
        final remoteJson = jsonEncode(currentRemote['payload']);
        if (remoteJson == localJson) {
          status.value = CloudSyncStatus.synced;
          return CloudSyncResult.unchanged;
        }

        // The device garden is authoritative. Use the revision read immediately
        // before the write so an update from another device cannot be silently
        // lost while this guarded overwrite is in flight.
        final revision = await backend.updateGarden(
          userId,
          remoteRevision,
          localPayload,
        );
        if (revision != null) {
          status.value = CloudSyncStatus.synced;
          return CloudSyncResult.synced;
        }

        if (attempt < 2) {
          remote = await backend.readGarden(userId);
          if (remote == null) break;
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
