import 'dart:convert';
import 'dart:io';

import 'package:bloom/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profiles =
      (jsonDecode(File('assets/data/plant_profiles.json').readAsStringSync())
              as Map<String, dynamic>)['profiles']
          as List;
  final credits =
      (jsonDecode(File('assets/data/image_credits.json').readAsStringSync())
              as Map<String, dynamic>)['credits']
          as List;

  test('every catalog image exists on disk', () {
    for (final p in profiles.cast<Map<String, dynamic>>()) {
      expect(File(p['asset'] as String).existsSync(), isTrue, reason: p['id']);
    }
    expect(File(plantPlaceholderAsset).existsSync(), isTrue);
  });

  test('every bundled plant photo has a credit with license and source', () {
    final credited = {
      for (final c in credits.cast<Map<String, dynamic>>()) c['asset'],
    };
    for (final p in profiles.cast<Map<String, dynamic>>()) {
      final asset = p['asset'] as String;
      if (asset.startsWith('assets/images/plants/')) {
        expect(credited, contains(asset), reason: p['id']);
      }
    }
    for (final c in credits.cast<Map<String, dynamic>>()) {
      expect(c['license'], isNotEmpty);
      expect((c['source'] as String).startsWith('https://'), isTrue);
    }
  });

  test('the old specific-plant placeholder maps to the drawn one', () {
    expect(
      normalizePlantAsset('assets/images/area-whole.png'),
      plantPlaceholderAsset,
    );
    expect(
      normalizePlantAsset('assets/images/snake.png'),
      'assets/images/snake.png',
    );
  });
}
