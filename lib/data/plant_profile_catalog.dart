import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

class PlantProfileCatalog {
  PlantProfileCatalog._(this.profiles);

  final List<PlantSpecies> profiles;
  static PlantProfileCatalog? _current;
  static PlantProfileCatalog get current =>
      _current ?? (throw StateError('Plant profiles have not been loaded.'));

  static Future<PlantProfileCatalog> load() async {
    final raw = await rootBundle.loadString('assets/data/plant_profiles.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final bundled = (json['profiles'] as List)
        .map((value) => PlantSpecies.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
    var profiles = bundled;
    try {
      final remoteProfiles = await _loadRemoteProfiles();
      if (remoteProfiles.isNotEmpty) profiles = remoteProfiles;
    } catch (_) {
      // Offline/unconfigured builds use the bundled catalog cache.
    }
    if (profiles.isEmpty) throw StateError('Plant profile catalog is empty.');
    PlantSpecies.setCatalog(profiles);
    final catalog = PlantProfileCatalog._(profiles);
    _current = catalog;
    return catalog;
  }

  static Future<List<PlantSpecies>> _loadRemoteProfiles() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('plant_profiles')
        .select(
          'id, common_name, scientific_name, asset_key, min_interval_days, max_interval_days, starting_interval_days, care_cue, light_requirement, light_placement, light_source_url, light_version, aliases:plant_profile_aliases(alias)',
        )
        .eq('active', true);
    return (rows as List)
        .map((row) {
          final value = Map<String, dynamic>.from(row as Map);
          final aliases = (value.remove('aliases') as List? ?? const [])
              .whereType<Map>()
              .map((alias) => alias['alias'] as String)
              .toList();
          return PlantSpecies(
            id: value['id'] as String,
            name: value['common_name'] as String,
            scientific: value['scientific_name'] as String,
            aliases: aliases,
            asset: value['asset_key'] as String,
            minDays: value['min_interval_days'] as int,
            maxDays: value['max_interval_days'] as int,
            startingIntervalDays: value['starting_interval_days'] as int,
            careCue: value['care_cue'] as String,
            light: PlantLightGuidance(
              requirement: value['light_requirement'] as String,
              placement: value['light_placement'] as String,
              sourceUrl: value['light_source_url'] as String,
              version: value['light_version'] as int,
            ),
          );
        })
        .toList(growable: false);
  }

  PlantSpecies? byId(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  static PlantSpecies byIdOrThrow(String id) => current.byId(id)!;

  PlantSpecies? resolve({
    String? typeId,
    String? name,
    String? scientificName,
  }) {
    final requestedId = typeId?.trim();
    if (requestedId != null && requestedId.isNotEmpty) {
      final profile = byId(requestedId);
      if (profile != null) return profile;
    }
    final values = [
      name,
      scientificName,
    ].whereType<String>().map(_normalize).where((value) => value.isNotEmpty);
    for (final value in values) {
      for (final profile in profiles) {
        if (_normalize(profile.name) == value ||
            _normalize(profile.scientific) == value ||
            profile.aliases.any((alias) => _normalize(alias) == value)) {
          return profile;
        }
      }
    }
    return null;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
