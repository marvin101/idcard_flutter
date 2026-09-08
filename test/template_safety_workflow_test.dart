import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/navigation/app_router.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';

const _sourceElement = DesignElement(
  id: 'source-element',
  type: DesignElementType.boundText,
  x: 3,
  y: 4,
  width: 20,
  height: 6,
  rotation: 17,
  zIndex: 9,
  locked: true,
  visible: false,
  style: {
    'color': '#123456',
    'effects': {
      'shadow': [1, 2, 3],
    },
  },
  data: {
    'field': 'full_name',
    'binding': {'prefix': 'Name: '},
  },
);

final _source = CardTemplate(
  name: 'Known good',
  updatedAt: DateTime.utc(2026, 9, 6),
  document: DesignDocument(
    canvas: const DesignCanvas(
      width: 90,
      height: 60,
      backgroundColor: '#ABCDEF',
      backgroundImage: 'background.png',
    ),
    elements: const [_sourceElement],
    settings: const {
      'snap_enabled': true,
      'nested': {
        'values': [1, 2],
      },
    },
  ),
);

class _Backend {
  _Backend() {
    api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/student-fields')) {
          return http.Response('[]', 200);
        }
        if (request.url.path.endsWith('/profile')) {
          return http.Response('{}', 404);
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/card-template')) {
          puts++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          lastExpectedToken = body['expected_updated_at'] as String?;
          if (pendingSave != null) return pendingSave!.future;
          if (networkFailure) throw http.ClientException('offline');
          if (failSave) {
            return http.Response(
              failureBody,
              failureStatus,
              headers: {'content-type': 'application/json'},
            );
          }
          if (malformedSaveResponse) return http.Response('{broken', 200);
          token = token.add(const Duration(microseconds: 1));
          stored = CardTemplate(
            name: body['name'] as String,
            document: DesignDocument.fromJson(
              Map<String, dynamic>.from(body['design'] as Map),
            ),
            updatedAt: token,
          );
          return _savedResponse(body, token);
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/card-template')) {
          gets++;
          return _savedResponse(stored.toApi(), token);
        }
        return http.Response('{}', 404);
      }),
    );
  }

  late final ApiService api;
  int puts = 0;
  int gets = 0;
  bool failSave = false;
  bool networkFailure = false;
  bool malformedSaveResponse = false;
  int failureStatus = 500;
  String failureBody = 'save failed';
  String? authoritativeName;
  String? lastExpectedToken;
  DateTime token = DateTime.utc(2026, 9, 6);
  CardTemplate stored = _source.deepCopy();
  Completer<http.Response>? pendingSave;

  http.Response _savedResponse(
    Map<String, dynamic> body,
    DateTime responseToken,
  ) => http.Response(
    jsonEncode({
      ...body,
      if (authoritativeName != null) 'name': authoritativeName,
      'uuid': 'server-template',
      'updated_at': responseToken.toIso8601String(),
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  void completePendingSave(CardTemplate template) {
    token = token.add(const Duration(microseconds: 1));
    stored = CardTemplate(
      name: template.name,
      document: template.document,
      updatedAt: token,
    );
    pendingSave!.complete(_savedResponse(template.toApi(), token));
  }
}

Future<_Backend> _mount(
  WidgetTester tester, {
  CardTemplate? initial,
  _Backend? existingBackend,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final backend = existingBackend ?? _Backend();
  if (existingBackend == null) addTearDown(backend.api.dispose);
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Center(child: Text('Cards screen'))),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => CardDesignerScreen(
        schoolUuid: 'school',
        api: backend.api,
        initialTemplate: initial ?? backend.stored,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

Future<void> _openAction(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('designer-template-actions')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _makeDirty(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('add-text')));
  await tester.pump();
}

CardTemplate _visibleTemplate(WidgetTester tester) {
  final view = tester.widget<DesignDocumentView>(
    find.byKey(const Key('designer-canvas')),
  );
  final name = tester
      .widget<TextField>(find.byKey(const Key('template-name')))
      .controller!
      .text;
  return CardTemplate(name: name, document: view.document);
}

bool _iconEnabled(WidgetTester tester, String tooltip) =>
    tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == tooltip,
          ),
        )
        .onPressed !=
    null;

void main() {
  test(
    'duplicate preserves content, regenerates identity, and deep-copies',
    () {
      var sequence = 0;
      final duplicate = _source.duplicateWorkingCopy(
        elementId: (element, index) => 'fresh-${sequence++}-$index',
      );

      expect(duplicate.name, 'Known good copy');
      expect(duplicate.updatedAt, isNull);
      expect(
        duplicate.document.canvas.toJson(),
        _source.document.canvas.toJson(),
      );
      expect(duplicate.document.settings, _source.document.settings);
      expect(duplicate.document.elements.single.id, isNot(_sourceElement.id));
      expect(
        duplicate.document.elements.single
            .copyWith(id: _sourceElement.id)
            .toJson(),
        _sourceElement.toJson(),
      );

      (duplicate.document.elements.single.style['effects'] as Map)['shadow'] = [
        9,
      ];
      (duplicate.document.elements.single.data['binding'] as Map)['prefix'] =
          'X';
      (duplicate.document.settings['nested'] as Map)['values'] = [7];
      expect(((_sourceElement.style['effects'] as Map)['shadow'] as List), [
        1,
        2,
        3,
      ]);
      expect((_sourceElement.data['binding'] as Map)['prefix'], 'Name: ');
      expect((_source.document.settings['nested'] as Map)['values'], [1, 2]);
    },
  );

  testWidgets(
    'duplicate is local, starts clean history, and cannot overwrite source',
    (tester) async {
      final backend = await _mount(tester);
      await _openAction(tester, 'Duplicate design');

      final duplicate = _visibleTemplate(tester);
      expect(
        duplicate.document.canvas.toJson(),
        _source.document.canvas.toJson(),
      );
      expect(duplicate.document.elements.single.id, isNot(_sourceElement.id));
      expect(find.text('Local duplicate • unsaved'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('designer-save')))
            .onPressed,
        isNull,
      );
      expect(_iconEnabled(tester, 'Undo'), isFalse);
      expect(backend.puts, 0);
    },
  );

  testWidgets('revert restores the exact saved snapshot and is undoable', (
    tester,
  ) async {
    await _mount(tester);
    await _makeDirty(tester);
    expect(_visibleTemplate(tester).document.elements.length, 2);

    await _openAction(tester, 'Revert to saved');
    await tester.tap(find.byKey(const Key('confirm-revert-design')));
    await tester.pumpAndSettle();
    expect(_visibleTemplate(tester).toApi(), _source.toApi());
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(_visibleTemplate(tester).document.elements.length, 2);
    expect(find.text('Unsaved changes'), findsOneWidget);
  });

  testWidgets('reset uses the canonical default and is one undo transaction', (
    tester,
  ) async {
    await _mount(tester);
    await _openAction(tester, 'Reset design');
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();

    expect(
      _visibleTemplate(tester).document.toJson(),
      CardTemplate.uploadedDesign.document.toJson(),
    );
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(_visibleTemplate(tester).toApi(), _source.toApi());
    expect(_iconEnabled(tester, 'Undo'), isFalse);
  });

  testWidgets('unsaved back Cancel stays and repeated pops show one dialog', (
    tester,
  ) async {
    await _mount(tester);
    await _makeDirty(tester);
    tester.binding.handlePopRoute();
    tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unsaved-cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('unsaved-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
  });

  testWidgets('router browser back is guarded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = _Backend();
    addTearDown(backend.api.dispose);
    late final AppRouterDelegate delegate;
    delegate = AppRouterDelegate(
      (location, _) => location == '/design'
          ? CardDesignerScreen(
              schoolUuid: 'school',
              api: backend.api,
              initialTemplate: _source,
            )
          : const Scaffold(body: Center(child: Text('Cards route'))),
    );
    await delegate.setNewRoutePath(const AppRouteState('/cards'));
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: const AppRouteInformationParser(),
        routeInformationProvider: PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(uri: Uri.parse('/cards')),
        ),
      ),
    );
    delegate.pushPage<void>('/design');
    await tester.pumpAndSettle();
    await _makeDirty(tester);

    final cancelledPop = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unsaved-cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('unsaved-cancel')));
    await tester.pumpAndSettle();
    await cancelledPop;
    expect(delegate.currentLocation, '/design');

    final discardedPop = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();
    await discardedPop;
    expect(delegate.currentLocation, '/cards');
    expect(find.text('Cards route'), findsOneWidget);
  });

  testWidgets('unsaved back Discard leaves and clean back does not warn', (
    tester,
  ) async {
    await _mount(tester);
    await _makeDirty(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();
    expect(find.text('Cards screen'), findsOneWidget);

    await _mount(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('Cards screen'), findsOneWidget);
  });

  testWidgets('Save and leave waits for success before navigating', (
    tester,
  ) async {
    final backend = await _mount(tester);
    backend.pendingSave = Completer<http.Response>();
    await _makeDirty(tester);
    final submitted = _visibleTemplate(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-save-leave')));
    await tester.pump();
    expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
    expect(find.text('Saving…'), findsOneWidget);

    backend.completePendingSave(submitted);
    await tester.pumpAndSettle();
    expect(find.text('Cards screen'), findsOneWidget);
    expect(backend.puts, 1);
  });

  testWidgets('failed Save and leave stays and preserves the saved snapshot', (
    tester,
  ) async {
    final backend = await _mount(tester);
    backend.failSave = true;
    await _makeDirty(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-save-leave')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
    expect(find.text('Save failed'), findsOneWidget);

    await _openAction(tester, 'Revert to saved');
    await tester.tap(find.byKey(const Key('confirm-revert-design')));
    await tester.pumpAndSettle();
    expect(_visibleTemplate(tester).toApi(), _source.toApi());
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('successful save becomes the authoritative revert snapshot', (
    tester,
  ) async {
    await _mount(tester);
    await tester.enterText(
      find.byKey(const Key('template-name')),
      'Saved revision',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('template-name')),
      'Later edit',
    );
    await tester.pump();
    await _openAction(tester, 'Revert to saved');
    await tester.tap(find.byKey(const Key('confirm-revert-design')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('template-name')))
          .controller!
          .text,
      'Saved revision',
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('successful save applies the authoritative server response', (
    tester,
  ) async {
    final backend = await _mount(tester);
    backend.authoritativeName = 'Server canonical name';
    await tester.enterText(
      find.byKey(const Key('template-name')),
      'Client draft name',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();

    expect(_visibleTemplate(tester).name, 'Server canonical name');
    expect(find.text('Saved'), findsOneWidget);
    expect(_iconEnabled(tester, 'Undo'), isTrue);
  });

  testWidgets('422 keeps edits dirty and retry succeeds', (tester) async {
    final backend = await _mount(tester);
    backend
      ..failSave = true
      ..failureStatus = 422
      ..failureBody = jsonEncode({
        'detail': [
          {
            'loc': ['body', 'design'],
            'msg': 'Value error, canvas.width must be a number',
          },
        ],
      });
    await _makeDirty(tester);
    final edited = _visibleTemplate(tester).toApi();

    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Validation failed'), findsOneWidget);
    expect(
      find.text('Template validation failed: canvas.width must be a number'),
      findsOneWidget,
    );
    expect(_visibleTemplate(tester).toApi(), edited);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('designer-save')))
          .onPressed,
      isNotNull,
    );

    backend.failSave = false;
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(backend.puts, 2);
  });

  testWidgets(
    '409 preserves edits and token, then Reload latest resets coherent history',
    (tester) async {
      final backend = await _mount(tester);
      backend
        ..failSave = true
        ..failureStatus = 409
        ..failureBody = jsonEncode({
          'detail': 'This card template changed after it was loaded.',
        });
      await _makeDirty(tester);
      final edited = _visibleTemplate(tester).toApi();

      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Conflict'), findsOneWidget);
      expect(_visibleTemplate(tester).toApi(), edited);
      expect(
        backend.lastExpectedToken,
        DateTime.utc(2026, 9, 6).toIso8601String(),
      );
      expect(find.byKey(const Key('reload-latest-template')), findsOneWidget);

      backend
        ..token = DateTime.utc(2026, 9, 8)
        ..stored = CardTemplate(
          name: 'Latest server design',
          document: CardTemplate.uploadedDesign.document,
          updatedAt: DateTime.utc(2026, 9, 8),
        );
      await tester.tap(find.byKey(const Key('reload-latest-template')));
      await tester.pumpAndSettle();

      expect(_visibleTemplate(tester).name, 'Latest server design');
      expect(find.text('Saved'), findsOneWidget);
      expect(_iconEnabled(tester, 'Undo'), isFalse);
      expect(backend.gets, 1);

      backend.failSave = false;
      await tester.enterText(
        find.byKey(const Key('template-name')),
        'Edit from latest',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('designer-save')));
      await tester.pumpAndSettle();
      expect(
        backend.lastExpectedToken,
        DateTime.utc(2026, 9, 8).toIso8601String(),
      );
    },
  );

  testWidgets('409 blocks Save and leave and keeps the editor dirty', (
    tester,
  ) async {
    final backend = await _mount(tester);
    backend
      ..failSave = true
      ..failureStatus = 409
      ..failureBody = jsonEncode({
        'detail': 'This card template changed after it was loaded.',
      });
    await _makeDirty(tester);
    final edited = _visibleTemplate(tester).toApi();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-save-leave')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
    expect(find.text('Conflict'), findsOneWidget);
    expect(_visibleTemplate(tester).toApi(), edited);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('designer-save')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('malformed save response preserves the working document', (
    tester,
  ) async {
    final backend = await _mount(tester);
    backend.malformedSaveResponse = true;
    await _makeDirty(tester);
    final edited = _visibleTemplate(tester).toApi();

    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Save failed'), findsOneWidget);
    expect(_visibleTemplate(tester).toApi(), edited);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('designer-save')))
          .onPressed,
      isNotNull,
    );

    await _openAction(tester, 'Revert to saved');
    await tester.tap(find.byKey(const Key('confirm-revert-design')));
    await tester.pumpAndSettle();
    expect(_visibleTemplate(tester).toApi(), _source.toApi());
  });

  testWidgets('network failure is recoverable without reloading', (
    tester,
  ) async {
    final backend = await _mount(tester);
    backend.networkFailure = true;
    await _makeDirty(tester);
    final edited = _visibleTemplate(tester).toApi();

    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Save failed'), findsOneWidget);
    expect(
      find.text(
        'Unable to save the template. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(_visibleTemplate(tester).toApi(), edited);

    backend.networkFailure = false;
    await tester.enterText(
      find.byKey(const Key('template-name')),
      'Edited after failure',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('saved template is reproduced after reopening', (tester) async {
    final backend = _Backend();
    addTearDown(backend.api.dispose);
    await _mount(tester, existingBackend: backend);
    await tester.enterText(
      find.byKey(const Key('template-name')),
      'Persisted B',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _mount(tester, existingBackend: backend);
    expect(_visibleTemplate(tester).name, 'Persisted B');
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('failed save leaves persisted template unchanged on reopen', (
    tester,
  ) async {
    final backend = _Backend()..failSave = true;
    addTearDown(backend.api.dispose);
    await _mount(tester, existingBackend: backend);
    await tester.enterText(
      find.byKey(const Key('template-name')),
      'Unpersisted B',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unsaved-discard')));
    await tester.pumpAndSettle();

    backend.failSave = false;
    await _mount(tester, existingBackend: backend);
    expect(_visibleTemplate(tester).toApi(), _source.toApi());
    expect(find.text('Saved'), findsOneWidget);
  });
}
