import 'dart:convert';
import 'dart:typed_data';

import 'package:bloom/data/plant_identifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this.response);

  final http.Response response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

XFile photo() => XFile.fromData(
  Uint8List.fromList([1, 2, 3]),
  name: 'plant.jpg',
  mimeType: 'image/jpeg',
);

SupabasePlantIdentifier identifier(String body, {int status = 200}) =>
    SupabasePlantIdentifier(
      endpoint: Uri.parse('https://example.test/identify'),
      client: FakeHttpClient(http.Response(body, status)),
    );

void main() {
  test('parses normalized candidate responses', () async {
    final result = await identifier(
      jsonEncode({
        'version': 'v1',
        'candidates': [
          {
            'scientificName': 'Epipremnum aureum',
            'commonNames': ['Pothos'],
            'score': 0.91,
          },
        ],
      }),
    ).identify([photo()]);

    expect(result.candidates, hasLength(1));
    expect(result.candidates.single.scientificName, 'Epipremnum aureum');
    expect(result.candidates.single.score, 0.91);
  });

  test('returns an empty result when the provider has no candidates', () async {
    final result = await identifier(
      jsonEncode({'candidates': []}),
    ).identify([photo()]);

    expect(result.candidates, isEmpty);
  });

  test('rejects malformed provider JSON', () async {
    expect(
      () => identifier('not-json').identify([photo()]),
      throwsA(isA<PlantIdentificationException>()),
    );
  });

  test('maps provider HTTP failures to a user-safe exception', () async {
    expect(
      () => identifier('{"error":"quota"}', status: 429).identify([photo()]),
      throwsA(
        predicate<PlantIdentificationException>(
          (error) => error.message.contains('429'),
        ),
      ),
    );
  });

  test('rejects more than five photos before making a request', () async {
    expect(
      () => identifier('{}').identify(List.generate(6, (_) => photo())),
      throwsA(isA<PlantIdentificationException>()),
    );
  });
}
