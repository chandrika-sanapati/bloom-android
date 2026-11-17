import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

enum CloudSyncResult {
  unavailable,
  signedOut,
  synced,
  unchanged,
  conflict,
  failed,
}

enum CloudSyncStatus {
  unavailable,
  signedOut,
  syncing,
  synced,
  conflict,
  failed,
}

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

class CloudGardenConflict {
  const CloudGardenConflict({required this.payload, required this.revision});

  final Map<String, dynamic> payload;
  final int revision;
}

class CloudGardenSync {
  // Keep the injectable backend seam while retaining a private field.
  CloudGardenSync({CloudGardenBackend? backend})
    // ignore: prefer_initializing_formals
    : _backend = backend;

  final CloudGardenBackend? _backend;
  final status = ValueNotifier<CloudSyncStatus>(CloudSyncStatus.unavailable);
  final message = ValueNotifier<String?>(null);
  int? _lastSyncedRevision;
  CloudGardenConflict? _conflict;

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
  CloudGardenConflict? get conflict => _conflict;

  Future<CloudSyncResult> sync(Garden garden) async {
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
      final remote = await backend.readGarden(userId);

      if (remote == null) {
        await backend.insertGarden(userId, localPayload);
        _remember(1, localJson);
        status.value = CloudSyncStatus.synced;
        return CloudSyncResult.synced;
      }

      final remoteRevision = (remote['revision'] as num?)?.toInt() ?? 0;
      final remoteJson = jsonEncode(remote['payload']);
      if (remoteJson == localJson) {
        _remember(remoteRevision, localJson);
        status.value = CloudSyncStatus.synced;
        return CloudSyncResult.unchanged;
      }

      // On a fresh process, a different remote payload is a conflict. After a
      // successful sync, update only if the remote revision is still ours.
      if (_lastSyncedRevision == null ||
          remoteRevision != _lastSyncedRevision) {
        _conflict = CloudGardenConflict(
          payload: Map<String, dynamic>.from(remote['payload'] as Map),
          revision: remoteRevision,
        );
        return _set(
          CloudSyncResult.conflict,
          'Cloud data changed on another device. Local data was not overwritten.',
        );
      }

      final revision = await backend.updateGarden(
        userId,
        remoteRevision,
        localPayload,
      );
      if (revision == null) {
        return _set(
          CloudSyncResult.conflict,
          'Cloud data changed while saving. Local data was not overwritten.',
        );
      }
      _remember(revision, localJson);
      status.value = CloudSyncStatus.synced;
      return CloudSyncResult.synced;
    } catch (_) {
      status.value = CloudSyncStatus.failed;
      message.value = 'Cloud sync failed. Your garden is still saved locally.';
      return CloudSyncResult.failed;
    }
  }

  Future<CloudSyncResult> resolveConflictKeepLocal(Garden garden) async {
    final backend = _activeBackend;
    final userId = backend?.userId;
    final conflict = _conflict;
    if (backend == null || userId == null || conflict == null) {
      return CloudSyncResult.failed;
    }
    final payload = garden.toJson();
    final revision = await backend.updateGarden(
      userId,
      conflict.revision,
      payload,
    );
    if (revision == null) {
      return _set(
        CloudSyncResult.conflict,
        'Cloud data changed again. Review the conflict and try again.',
      );
    }
    _remember(revision, jsonEncode(payload));
    _conflict = null;
    status.value = CloudSyncStatus.synced;
    message.value = 'This device garden is now synced.';
    return CloudSyncResult.synced;
  }

  Future<Garden?> cloudGarden() async {
    final payload = _conflict?.payload;
    if (payload == null) return null;
    return Garden.fromJson(payload);
  }

  void clearConflict() => _conflict = null;

  void _remember(int revision, String payload) {
    _lastSyncedRevision = revision;
  }

  CloudSyncResult _set(CloudSyncResult result, String text) {
    status.value = switch (result) {
      CloudSyncResult.conflict => CloudSyncStatus.conflict,
      CloudSyncResult.failed => CloudSyncStatus.failed,
      CloudSyncResult.signedOut => CloudSyncStatus.signedOut,
      _ => CloudSyncStatus.unavailable,
    };
    message.value = text;
    return result;
  }
}
