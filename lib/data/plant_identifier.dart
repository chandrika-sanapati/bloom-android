import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/plant_identification.dart';

abstract interface class PlantIdentifier {
  Future<PlantIdentificationResult> identify(
    List<XFile> photos, {
    String? accessToken,
  });
}

class PlantIdentificationException implements Exception {
  const PlantIdentificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls a Supabase Edge Function, never PlantNet directly from the app.
class SupabasePlantIdentifier implements PlantIdentifier {
  // Keep the public endpoint parameter while retaining a private client seam.
  SupabasePlantIdentifier({required Uri endpoint, http.Client? client})
    // ignore: prefer_initializing_formals
    : _endpoint = endpoint,
      _client = client ?? http.Client();

  final Uri _endpoint;
  final http.Client _client;

  @override
  Future<PlantIdentificationResult> identify(
    List<XFile> photos, {
    String? accessToken,
  }) async {
    if (photos.isEmpty || photos.length > 5) {
      throw const PlantIdentificationException(
        'Choose between one and five photos of the same plant.',
      );
    }

    final request = http.MultipartRequest('POST', _endpoint);
    final token = accessToken ?? _currentAccessToken();
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (publishableKey.isNotEmpty) {
      request.headers['apikey'] = publishableKey;
    }
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    for (final photo in photos) {
      final bytes = await photo.readAsBytes().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw const PlantIdentificationException(
          'Reading the selected photo timed out. Try another image.',
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: photo.name,
          contentType: _contentType(photo.name),
        ),
      );
    }

    const timeout = Duration(seconds: 30);
    final response = await _client.send(request).timeout(
      timeout,
      onTimeout: () => throw const PlantIdentificationException(
        'Plant identification timed out. Check your connection and try again.',
      ),
    );
    final body = await response.stream.bytesToString().timeout(
      timeout,
      onTimeout: () => throw const PlantIdentificationException(
        'Plant identification timed out. Check your connection and try again.',
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlantIdentificationException(
        'Plant identification is unavailable right now (${response.statusCode}).',
      );
    }

    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final rawResults = json['candidates'] as List? ?? const [];
      final candidates = rawResults
          .whereType<Map>()
          .map(_candidateFromJson)
          .whereType<PlantCandidate>()
          .toList();
      return PlantIdentificationResult(
        candidates: candidates,
        providerVersion: json['version'] as String?,
        remainingRequests: json['remainingIdentificationRequests'] as int?,
      );
    } catch (_) {
      throw const PlantIdentificationException(
        'The identification service returned an invalid result.',
      );
    }
  }

  MediaType _contentType(String filename) =>
      filename.toLowerCase().endsWith('.png')
      ? MediaType('image', 'png')
      : MediaType('image', 'jpeg');

  PlantCandidate? _candidateFromJson(Map raw) {
    final normalizedScientific = raw['scientificName'];
    if (normalizedScientific is String && normalizedScientific.isNotEmpty) {
      final normalizedNames = (raw['commonNames'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final normalizedScore = raw['score'];
      return PlantCandidate(
        scientificName: normalizedScientific,
        commonNames: normalizedNames,
        score: normalizedScore is num ? normalizedScore.toDouble() : 0,
        gbifId: raw['gbifId']?.toString(),
        powoId: raw['powoId']?.toString(),
      );
    }
    final species = raw['species'];
    if (species is! Map) return null;
    final scientific = species['scientificNameWithoutAuthor'];
    if (scientific is! String || scientific.trim().isEmpty) return null;
    final names =
        (species['commonNames'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final score = raw['score'];
    final gbif = raw['gbif'];
    final powo = raw['powo'];
    return PlantCandidate(
      scientificName: scientific,
      commonNames: names,
      score: score is num ? score.toDouble() : 0,
      gbifId: gbif is Map ? gbif['id']?.toString() : null,
      powoId: powo is Map ? powo['id']?.toString() : null,
    );
  }

  String? _currentAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}

PlantIdentifier? configuredPlantIdentifier() {
  const endpoint = String.fromEnvironment('PLANT_IDENTIFIER_ENDPOINT');
  if (endpoint.isEmpty) return null;
  final uri = Uri.tryParse(endpoint);
  return uri == null ? null : SupabasePlantIdentifier(endpoint: uri);
}
