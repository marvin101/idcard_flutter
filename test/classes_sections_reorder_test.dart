import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/screens/classes_sections_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

void main() {
  testWidgets(
    'class grip reorders four rows with an aligned fixed-width proxy',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1000);
      addTearDown(() => tester.view.resetPhysicalSize());
      final classes = [
        for (var i = 1; i <= 4; i++)
          {'uuid': 'class-$i', 'name': 'Class $i', 'sort_order': i - 1},
      ];
      List<String>? persisted;
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/schools/school-1/classes') {
            return http.Response(jsonEncode(classes), 200);
          }
          if (request.method == 'GET' &&
              request.url.path.endsWith('/sections')) {
            return http.Response('[]', 200);
          }
          if (request.method == 'PUT' &&
              request.url.path == '/schools/school-1/classes/order') {
            persisted = (jsonDecode(request.body)['class_uuids'] as List)
                .cast<String>();
            return http.Response(
              jsonEncode([
                for (final uuid in persisted!)
                  classes.firstWhere((item) => item['uuid'] == uuid),
              ]),
              200,
            );
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ClassesSectionsScreen(
            schoolUuid: 'school-1',
            schoolName: 'School',
            api: api,
            canManage: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = find.byKey(const ValueKey('class-order-class-1'));
      final handle = find.byKey(const ValueKey('class-reorder-handle-class-1'));
      final widthBefore = tester.getSize(first).width;
      final leftBefore = tester.getTopLeft(first).dx;
      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('class-order-class-4'))),
        timeStamp: const Duration(milliseconds: 400),
      );
      await tester.pump();
      expect(tester.getSize(first).width, closeTo(widthBefore, .01));
      expect(tester.getTopLeft(first).dx, closeTo(leftBefore, .01));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(persisted, isNotNull);
      expect(
        persisted,
        isNot(equals(['class-1', 'class-2', 'class-3', 'class-4'])),
      );
      expect(persisted!.toSet(), {'class-1', 'class-2', 'class-3', 'class-4'});

      persisted = null;
      final tileDrag = await tester.startGesture(
        tester.getCenter(find.text('Class 2')),
        kind: PointerDeviceKind.mouse,
      );
      await tileDrag.moveBy(const Offset(0, 100));
      await tileDrag.up();
      await tester.pumpAndSettle();
      expect(persisted, isNull, reason: 'only the drag grip may reorder rows');
      expect(tester.takeException(), isNull);
    },
  );
}
