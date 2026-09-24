import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/auth_models.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

const _sourceUuid = '11111111-1111-4111-8111-111111111111';
const _destinationUuid = '22222222-2222-4222-8222-222222222222';
const _unauthorizedUuid = '33333333-3333-4333-8333-333333333333';

const _destination = SchoolSummary(
  uuid: _destinationUuid,
  code: 'DEST',
  name: 'St. Xavier School',
  isActive: true,
);

Map<String, dynamic> _templateResponse({
  String name = 'Uploaded blue school card',
}) => {
  ...CardTemplate.uploadedDesign.copyWith(name: name).toApi(),
  'uuid': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'updated_at': '2026-09-24T08:00:00Z',
};

Future<void> _pumpDesigner(
  WidgetTester tester,
  MockClient client, {
  List<SchoolSummary> destinations = const [_destination],
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiService(client: client, baseUrl: 'http://test');
  addTearDown(api.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: CardDesignerScreen(
        schoolUuid: _sourceUuid,
        api: api,
        initialTemplate: CardTemplate.uploadedDesign,
        copyDestinations: destinations,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCopyDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('designer-template-actions')));
  await tester.pumpAndSettle();
  expect(find.text('Copy design to another school…'), findsOneWidget);
  await tester.tap(find.text('Copy design to another school…'));
  await tester.pumpAndSettle();
}

Future<void> _selectDestination(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('copy-destination-$_destinationUuid')),
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('continue-copy-design')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'copy action lists only supplied authorized destination schools',
    (tester) async {
      final client = MockClient((request) async => http.Response('[]', 200));
      await _pumpDesigner(tester, client);

      await _openCopyDialog(tester);

      expect(find.text('St. Xavier School'), findsOneWidget);
      expect(find.text('DEST'), findsOneWidget);
      expect(find.text(_sourceUuid), findsNothing);
      expect(find.text(_unauthorizedUuid), findsNothing);
    },
  );

  testWidgets(
    'existing destination requires confirmation and cancel does not copy',
    (tester) async {
      var copyRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/card-template') &&
            request.url.path.contains(_destinationUuid)) {
          return http.Response(
            jsonEncode(_templateResponse(name: 'Existing')),
            200,
          );
        }
        if (request.url.path.endsWith('/card-template/copy')) {
          copyRequests++;
        }
        return http.Response('[]', 200);
      });
      await _pumpDesigner(tester, client);

      await _openCopyDialog(tester);
      await _selectDestination(tester);

      expect(
        find.text(
          'St. Xavier School already has a card design. Copying this design will replace its existing design.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(copyRequests, 0);
    },
  );

  testWidgets(
    'successful copy keeps source open and shows destination feedback',
    (tester) async {
      Map<String, dynamic>? copyBody;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/card-template') &&
            request.url.path.contains(_destinationUuid)) {
          return http.Response('{"detail":"missing"}', 404);
        }
        if (request.url.path.endsWith('/card-template/copy')) {
          copyBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_templateResponse()), 200);
        }
        return http.Response('[]', 200);
      });
      await _pumpDesigner(tester, client);

      await _openCopyDialog(tester);
      await _selectDestination(tester);
      expect(
        find.text('Copy this card design to St. Xavier School?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-copy-design')));
      await tester.pumpAndSettle();

      expect(copyBody, {'source_school_uuid': _sourceUuid});
      expect(
        find.text('Card design copied to St. Xavier School.'),
        findsOneWidget,
      );
      expect(find.text('Card designer'), findsOneWidget);
    },
  );

  testWidgets('unmapped custom fields are shown without corrupting the source', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/card-template') &&
          request.url.path.contains(_destinationUuid)) {
        return http.Response('{"detail":"missing"}', 404);
      }
      if (request.url.path.endsWith('/card-template/copy')) {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'unmapped_custom_fields',
              'message':
                  'Some fields in this design do not exist in the destination school.',
              'unresolved_fields': [
                {
                  'field_uuid': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                  'field_key': 'house',
                  'label': 'House',
                  'entity_type': 'student',
                  'reason':
                      'No destination custom field has the same field key.',
                },
              ],
            },
          }),
          422,
        );
      }
      return http.Response('[]', 200);
    });
    await _pumpDesigner(tester, client);

    await _openCopyDialog(tester);
    await _selectDestination(tester);
    await tester.tap(find.byKey(const Key('confirm-copy-design')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Fields requiring attention'), findsOneWidget);
    expect(find.text('House'), findsOneWidget);
    expect(find.textContaining('student • house'), findsOneWidget);
    expect(find.text('Card designer'), findsOneWidget);
  });

  testWidgets('no eligible school produces a clear message', (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));
    await _pumpDesigner(tester, client, destinations: const []);
    await _openCopyDialog(tester);
    expect(find.text('No destination schools'), findsOneWidget);
    expect(
      find.text(
        'You do not administer any other schools that can receive this design.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('existing local Duplicate design action remains unchanged', (
    tester,
  ) async {
    final client = MockClient((request) async => http.Response('[]', 200));
    await _pumpDesigner(tester, client);

    await tester.tap(find.byKey(const Key('designer-template-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate design'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Local duplicate created.'), findsOneWidget);
  });
}
