import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

enum CloudSyncResult { unavailable, signedOut, synced, unchanged, conflict }

class CloudGardenSync {
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
    if (client == null) return CloudSyncResult.unavailable;
    if (user == null) return CloudSyncResult.signedOut;

    final localPayload = garden.toJson();
    final localJson = jsonEncode(localPayload);
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
      return CloudSyncResult.synced;
    }

    if (jsonEncode(remote['payload']) == localJson) {
      return CloudSyncResult.unchanged;
    }

    // Never overwrite another device's garden implicitly. A future merge UI
    // can present both payloads and retry with an explicit revision.
    return CloudSyncResult.conflict;
  }
}
