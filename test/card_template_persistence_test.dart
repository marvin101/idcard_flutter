import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/services/api_service.dart';

Map<String, dynamic> _validTemplate({String name = 'Persisted'}) => {
  'uuid': '11111111-1111-1111-1111-111111111111',
  'name': name,
  'design': CardTemplate.uploadedDesign.document.toJson(),
  'updated_at': '2026-09-07T00:00:00Z',
};

void main() {
  test('GET loads valid v2 and legacy v1 templates', () async {
    var legacy = false;
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((_) async {
        final body = legacy
            ? {
                'name': 'Legacy',
                'design': {'version': 1, 'school_title': 'Legacy School'},
              }
            : _validTemplate();
        return http.Response(jsonEncode(body), 200);
      }),
    );
    addTearDown(api.dispose);

    expect((await api.getCardTemplate('school')).name, 'Persisted');
    legacy = true;
    final loaded = await api.getCardTemplate('school');
    expect(loaded.name, 'Legacy');
    expect(loaded.document.settings['migrated_from_v1'], isTrue);
  });

  test('GET distinguishes missing templates from invalid responses', () async {
    var response = http.Response(
      jsonEncode({'detail': 'This school does not have a card template yet'}),
      404,
    );
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((_) async => response),
    );
    addTearDown(api.dispose);

    await expectLater(
      api.getCardTemplate('school'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having(
              (error) => error.message,
              'message',
              contains('does not have'),
            ),
      ),
    );

    response = http.Response('{malformed', 200);
    await expectLater(
      api.getCardTemplate('school'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'The server returned an invalid card template.',
        ),
      ),
    );
  });

  test('GET preserves network and server failures as load failures', () async {
    var networkFailure = true;
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((_) async {
        if (networkFailure) throw http.ClientException('offline');
        return http.Response(
          jsonEncode({'detail': 'Database unavailable'}),
          500,
        );
      }),
    );
    addTearDown(api.dispose);

    await expectLater(
      api.getCardTemplate('school'),
      throwsA(isA<http.ClientException>()),
    );
    networkFailure = false;
    await expectLater(
      api.getCardTemplate('school'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having(
              (error) => error.message,
              'message',
              'Database unavailable',
            ),
      ),
    );
  });

  test('GET rejects unsupported schemas and invalid field types', () async {
    Map<String, dynamic> body = {
      'name': 'Future',
      'design': {'schema_version': 3},
    };
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
    );
    addTearDown(api.dispose);

    await expectLater(
      api.getCardTemplate('school'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('unsupported schema version'),
        ),
      ),
    );

    body = {
      'name': 'Invalid',
      'design': {
        'schema_version': 2,
        'canvas': {'width': false, 'height': 53.98},
        'elements': <dynamic>[],
      },
    };
    await expectLater(
      api.getCardTemplate('school'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'The server returned an invalid card template.',
        ),
      ),
    );
  });

  test('PUT exposes useful 422 detail without raw JSON', () async {
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'design'],
                'msg': 'Value error, canvas.width must be a number',
              },
            ],
          }),
          422,
        ),
      ),
    );
    addTearDown(api.dispose);

    await expectLater(
      api.saveCardTemplate('school', CardTemplate.uploadedDesign),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having(
              (error) => error.message,
              'message',
              'body.design: Value error, canvas.width must be a number',
            ),
      ),
    );
  });

  test('PUT rejects malformed and unsupported success responses', () async {
    var response = http.Response('[]', 200);
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((_) async => response),
    );
    addTearDown(api.dispose);

    await expectLater(
      api.saveCardTemplate('school', CardTemplate.uploadedDesign),
      throwsA(isA<ApiException>()),
    );

    response = http.Response(
      jsonEncode({
        'name': 'Future',
        'design': {'schema_version': 7},
      }),
      200,
    );
    await expectLater(
      api.saveCardTemplate('school', CardTemplate.uploadedDesign),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('unsupported schema version'),
        ),
      ),
    );
  });
}
