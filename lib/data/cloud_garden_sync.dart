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

class CloudGardenSync {
  final status = ValueNotifier<CloudSyncStatus>(CloudSyncStatus.unavailable);
  final message = ValueNotifier<String?>(null);
  int? _lastSyncedRevision;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get configured => _client != null;
  bool get signedIn => _client?.auth.currentSession != null;

  Future<CloudSyncResult> sync(Garden garden) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null) {
      return _set(CloudSyncResult.unavailable, 'Cloud sync is not configured.');
    }
    if (user == null) {
      return _set(CloudSyncResult.signedOut, 'Sign in to sync your garden.');
    }

    status.value = CloudSyncStatus.syncing;
    message.value = null;
    final localPayload = garden.toJson();
    final localJson = jsonEncode(localPayload);
    try {
      final remote = await client
          .from('gardens')
          .select('payload, revision')
          .eq('user_id', user.id)
          .maybeSingle();

      if (remote == null) {
        await client.from('gardens').insert({
          'user_id': user.id,
          'schema_version': 1,
          'payload': localPayload,
          'revision': 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
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
        return _set(
          CloudSyncResult.conflict,
          'Cloud data changed on another device. Local data was not overwritten.',
        );
      }

      final updated = await client
          .from('gardens')
          .update({
            'payload': localPayload,
            'schema_version': 1,
            'revision': remoteRevision + 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('revision', remoteRevision)
          .select('revision')
          .maybeSingle();
      if (updated == null) {
        return _set(
          CloudSyncResult.conflict,
          'Cloud data changed while saving. Local data was not overwritten.',
        );
      }
      final revision =
          (updated['revision'] as num?)?.toInt() ?? remoteRevision + 1;
      _remember(revision, localJson);
      status.value = CloudSyncStatus.synced;
      return CloudSyncResult.synced;
    } catch (_) {
      status.value = CloudSyncStatus.failed;
      message.value = 'Cloud sync failed. Your garden is still saved locally.';
      return CloudSyncResult.failed;
    }
  }

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
