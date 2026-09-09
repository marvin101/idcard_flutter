import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/public_design.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/navigation/app_router.dart';
import 'package:idcard_flutter/screens/public_design_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/authenticated_shell.dart';
import 'package:idcard_flutter/widgets/public_design_share_button.dart';

class _FakeApi extends ApiService {
  _FakeApi({this.failure, this.failOnce = false});

  final Object? failure;
  final bool failOnce;
  var share = const PublicDesignShare(enabled: false);
  int publicLoads = 0;

  static final view = PublicDesignView(
    template: CardTemplate.uploadedDesign,
    school: const SchoolProfile(
      uuid: 'school',
      schoolCode: 'SCH-01',
      schoolName: 'Campus School',
      isActive: true,
    ),
  );

  @override
  Future<PublicDesignView> getPublicDesign(String token) async {
    publicLoads += 1;
    if (failure != null && (!failOnce || publicLoads == 1)) throw failure!;
    return view;
  }

  @override
  Future<PublicDesignShare> getPublicDesignShare(String schoolUuid) async {
    if (failure != null) throw failure!;
    return share;
  }

  @override
  Future<PublicDesignShare> updatePublicDesignShare({
    required String schoolUuid,
    required bool enabled,
  }) async {
    share = PublicDesignShare(
      enabled: enabled,
      publicToken: enabled ? 'opaque-token' : share.publicToken,
    );
    return share;
  }

  @override
  Future<PublicDesignShare> regeneratePublicDesignShare(
    String schoolUuid,
  ) async {
    share = const PublicDesignShare(
      enabled: true,
      publicToken: 'replacement-token',
    );
    return share;
  }
}

void main() {
  test('public design route is anonymous and token-safe', () {
    final route = AppRoutes.publicDesign('opaque/token');
    expect(route, '/public/designs/opaque%2Ftoken');
    expect(AppRoutes.isPublicDesign(route), isTrue);
    expect(AppRoutes.publicDesignToken(route), 'opaque/token');
    expect(AppRoutes.isProtected(route), isFalse);
  });

  test('route parser preserves direct and hash public design links', () async {
    const parser = AppRouteInformationParser();
    final direct = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/public/designs/opaque-token')),
    );
    final hash = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/#/public/designs/opaque-token')),
    );

    expect(direct.location, '/public/designs/opaque-token');
    expect(hash.location, '/public/designs/opaque-token');
  });

  test(
    'public design API uses the anonymous endpoint without auth headers',
    () async {
      late http.Request request;
      final api = ApiService(
        baseUrl: 'https://api.example.test',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode({
              'name': 'Shared card',
              'design': CardTemplate.uploadedDesign.document.toJson(),
              'school': {
                'uuid': 'school',
                'school_code': 'SCH-01',
                'school_name': 'Campus School',
                'email': null,
                'phone': null,
                'website': null,
                'address': null,
                'city': null,
                'district': null,
                'state': null,
                'country': 'India',
                'postal_code': null,
                'principal_name': null,
                'logo_url': null,
              },
            }),
            200,
          );
        }),
      );

      final view = await api.getPublicDesign('opaque/token');
      expect(request.url.path, '/public/designs/opaque%2Ftoken');
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(view.template.name, 'Shared card');
      expect(view.school.schoolName, 'Campus School');
    },
  );

  testWidgets(
    'public page renders the shared document outside authenticated UI',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicDesignScreen(token: 'token', api: _FakeApi()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthenticatedShell), findsNothing);
      expect(find.text('Campus School'), findsOneWidget);
      expect(find.byKey(const Key('public-design-name')), findsOneWidget);
      expect(find.text('Sample Student'), findsOneWidget);
      expect(find.text('Read-only preview'), findsNothing);
      expect(find.byKey(const Key('design-document-surface')), findsOneWidget);
    },
  );

  testWidgets('unavailable public design is generic and retryable', (
    tester,
  ) async {
    final api = _FakeApi(
      failure: const ApiException(404, 'Not found'),
      failOnce: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicDesignScreen(token: 'bad', api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This design preview is unavailable.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(api.publicLoads, 2);
  });

  testWidgets('administrator can enable the saved-design share link', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicDesignShareButton(schoolUuid: 'school', api: api),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('public-design-share')));
    await tester.pumpAndSettle();
    expect(find.text('Share saved design'), findsWidgets);

    await tester.tap(find.byKey(const Key('public-design-enabled')));
    await tester.pumpAndSettle();
    expect(api.share.enabled, isTrue);
    expect(find.byKey(const Key('public-design-link')), findsOneWidget);
    expect(find.textContaining('/public/designs/opaque-token'), findsOneWidget);
  });
}
