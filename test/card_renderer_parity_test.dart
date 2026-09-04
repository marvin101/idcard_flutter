import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/academic_session.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/school_class.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/models/section.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/screens/cards_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/services/pdf_service.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';
import 'package:idcard_flutter/widgets/id_card_preview.dart';

const actualStudent = ApiStudent(
  uuid: 'student',
  sessionUuid: 'session',
  classUuid: 'class',
  sectionUuid: 'section',
  admissionNo: 'ADM-2026',
  fullName: 'Asha Singh',
  bloodGroup: 'B+',
  address: 'Student address',
  photoPath: '/photo.png',
  isActive: true,
  customFields: [StudentCustomFieldValue(fieldUuid: 'house', value: 'Blue')],
);
const school = SchoolProfile(
  uuid: 'school',
  schoolCode: 'ABC',
  schoolName: 'Parity School',
  address: 'School address',
  logoUrl: '/logo.png',
  isActive: true,
);

CardTemplate fixture(bool portrait) {
  final w = portrait ? 53.98 : 85.60;
  final h = portrait ? 85.60 : 53.98;
  DesignElement text(String id, String field, double y, {bool bound = true}) =>
      DesignElement(
        id: id,
        type: bound ? DesignElementType.boundText : DesignElementType.text,
        x: 3,
        y: h * y,
        width: w - 6,
        height: 5,
        rotation: id == 'name' ? 7 : 0,
        zIndex: 2,
        style: {
          'font_size': 2.5,
          'font_weight': 700,
          'alignment': 'center',
          'color': '#123456',
          'max_lines': 1,
        },
        data: {bound ? 'field' : 'text': field},
      );
  return CardTemplate.fromApi(
    CardTemplate(
      name: 'Parity',
      document: DesignDocument(
        canvas: DesignCanvas(
          width: w,
          height: h,
          orientation: portrait ? 'portrait' : 'landscape',
          backgroundColor: '#FAF3DD',
          backgroundImage: '/background.png',
        ),
        settings: const {'snap_enabled': false, 'grid_enabled': false},
        elements: [
          DesignElement(
            id: 'header',
            type: DesignElementType.rectangle,
            x: 0,
            y: 0,
            width: w,
            height: h * .19,
            style: const {
              'fill_color': '#AABBCC',
              'border_color': '#112233',
              'border_width': .2,
              'corner_radius': .5,
            },
          ),
          DesignElement(
            id: 'footer',
            type: DesignElementType.rectangle,
            x: 0,
            y: h * .9,
            width: w,
            height: h * .1,
            style: const {'fill_color': '#334455'},
          ),
          text('school', 'school_name', .01),
          text('address', 'school_address', .10),
          text('static', 'STUDENT CARD', .84, bound: false),
          text('name', 'full_name', .45),
          text('admission', 'admission_no', .54),
          text('blood', 'blood_group', .63),
          text('class', 'class', .72),
          text('section', 'section', .78),
          DesignElement(
            id: 'custom',
            type: DesignElementType.customFieldText,
            x: 2,
            y: h * .91,
            width: w - 4,
            height: 4,
            zIndex: 3,
            data: const {'field_uuid': 'house', 'fallback': 'Sample house'},
            style: const {
              'font_size': 2.0,
              'alignment': 'right',
              'color': '#FFFFFF',
            },
          ),
          DesignElement(
            id: 'photo',
            type: DesignElementType.studentPhoto,
            x: w * .3,
            y: h * .2,
            width: w * .25,
            height: h * .23,
            zIndex: 1,
            style: const {
              'fit': 'cover',
              'border_color': '#778899',
              'border_width': .3,
              'corner_radius': 1.0,
            },
          ),
          DesignElement(
            id: 'logo',
            type: DesignElementType.schoolLogo,
            x: w * .75,
            y: h * .2,
            width: 8,
            height: 8,
            zIndex: 1,
            style: const {
              'fit': 'contain',
              'border_width': .2,
              'corner_radius': .7,
            },
          ),
          DesignElement(
            id: 'line',
            type: DesignElementType.line,
            x: 3,
            y: h * .88,
            width: w - 6,
            height: 1,
            zIndex: 2,
            style: const {'border_width': .25, 'color': '#654321'},
          ),
          const DesignElement(
            id: 'hidden',
            type: DesignElementType.rectangle,
            x: 0,
            y: 0,
            width: 20,
            height: 20,
            visible: false,
          ),
        ],
      ),
    ).toApi(),
  );
}

class ParityApi extends ApiService {
  ParityApi(this.template) : super(baseUrl: 'https://assets.invalid');
  CardTemplate template;
  int templateReads = 0;
  @override
  Future<CardTemplate> getCardTemplate(String schoolUuid) async {
    templateReads++;
    return template;
  }

  @override
  Future<SchoolProfile> getSchoolProfile(String schoolUuid) async => school;
  @override
  Future<List<StudentFieldDefinition>> getStudentFields(
    String schoolUuid, {
    bool includeInactive = false,
  }) async => [];
  @override
  Future<List<AcademicSession>> getAcademicSessions(
    String schoolUuid,
  ) async => [
    const AcademicSession(uuid: 'session', name: '2026-27', isCurrent: true),
  ];
  @override
  Future<List<SchoolClass>> getClasses(String schoolUuid) async => [
    const SchoolClass(uuid: 'class', name: 'X'),
  ];
  @override
  Future<List<SchoolSection>> getSections({
    required String schoolUuid,
    required String classUuid,
  }) async => [const SchoolSection(uuid: 'section', name: 'A')];
  @override
  Future<ApiStudentPage> getStudentsPage({
    required String schoolUuid,
    int limit = 100,
    int offset = 0,
    String? search,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
    DateTime? createdFrom,
    DateTime? createdTo,
    String? verificationStatus,
    bool? printed,
  }) async => ApiStudentPage(
    items: [actualStudent],
    total: 1,
    offset: 0,
    limit: limit,
    hasMore: false,
  );
}

Widget cards(ParityApi api) => CardsScreen(
  schoolUuid: 'school',
  schoolName: school.schoolName,
  api: api,
  canEdit: true,
  canDesign: true,
  canPrint: true,
);

Finder element(Finder scope, String id) =>
    find.descendant(of: scope, matching: find.byKey(Key('design-element-$id')));

Map<String, List<double>> inspect(
  WidgetTester t,
  Finder scope,
  CardTemplate template,
) {
  final surface = find
      .descendant(
        of: scope,
        matching: find.byKey(const Key('design-document-surface')),
      )
      .first;
  final surfaceRect = t.getRect(surface);
  final scale = surfaceRect.width / template.document.canvas.width;
  expect(
    surfaceRect.width / surfaceRect.height,
    closeTo(
      template.document.canvas.width / template.document.canvas.height,
      .000001,
    ),
  );
  expect(t.widget<ColoredBox>(surface).color, const Color(0xfffaf3dd));
  final result = <String, List<double>>{};
  for (final e in template.document.elements) {
    final target = element(scope, e.id);
    if (!e.visible) {
      expect(target, findsNothing);
      continue;
    }
    final rect = t.getRect(target);
    final geometry = [
      (rect.left - surfaceRect.left) / scale,
      (rect.top - surfaceRect.top) / scale,
      rect.width / scale,
      rect.height / scale,
    ];
    for (var i = 0; i < 4; i++) {
      expect(geometry[i], closeTo([e.x, e.y, e.width, e.height][i], .000001));
    }
    final transform = t.widget<Transform>(
      find.descendant(of: target, matching: find.byType(Transform)).first,
    );
    result[e.id] = [...geometry, ...transform.transform.storage];
    if ([
      DesignElementType.text,
      DesignElementType.boundText,
      DesignElementType.customFieldText,
    ].contains(e.type)) {
      final text = t.widget<Text>(
        find.descendant(of: target, matching: find.byType(Text)).first,
      );
      final mmSize = (e.style['font_size'] as num?)?.toDouble() ?? 3;
      expect(text.style!.fontSize! / scale, closeTo(mmSize, .000001));
      expect(
        text.style!.fontWeight,
        e.id == 'custom' ? FontWeight.w400 : FontWeight.w700,
      );
      expect(
        text.textAlign,
        e.id == 'custom' ? TextAlign.right : TextAlign.center,
      );
      expect(
        text.style!.color,
        e.id == 'custom' ? Colors.white : const Color(0xff123456),
      );
      result[e.id]!.add(text.style!.fontSize! / scale);
    }
    if (e.type == DesignElementType.rectangle) {
      final decoration = t
          .widgetList<DecoratedBox>(
            find.descendant(of: target, matching: find.byType(DecoratedBox)),
          )
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null);
      final border = decoration.border as Border;
      expect(
        border.top.width / scale,
        closeTo((e.style['border_width'] as num?)?.toDouble() ?? 0, .000001),
      );
    }
    if ([
      DesignElementType.studentPhoto,
      DesignElementType.schoolLogo,
    ].contains(e.type)) {
      final container = t
          .widgetList<Container>(
            find.descendant(of: target, matching: find.byType(Container)),
          )
          .firstWhere((w) => w.clipBehavior == Clip.antiAlias);
      final d = container.decoration! as BoxDecoration;
      expect(
        (d.border! as Border).top.width / scale,
        closeTo(e.style['border_width'] as num, .000001),
      );
      expect(
        (d.borderRadius! as BorderRadius).topLeft.x / scale,
        closeTo(e.style['corner_radius'] as num, .000001),
      );
      final images = t.widgetList<Image>(
        find.descendant(of: target, matching: find.byType(Image)),
      );
      if (images.isNotEmpty) {
        expect(
          images.single.fit,
          e.id == 'logo' ? BoxFit.contain : BoxFit.cover,
        );
      }
    }
    if (e.type == DesignElementType.line) {
      final line = t.widget<Container>(
        find.descendant(of: target, matching: find.byType(Container)),
      );
      expect(line.constraints!.maxHeight / scale, closeTo(.25, .000001));
    }
  }
  return result;
}

void main() {
  for (final portrait in [true, false]) {
    testWidgets(
      '${portrait ? 'portrait' : 'landscape'} Designer and actual Cards screen share geometry and style',
      (t) async {
        await t.binding.setSurfaceSize(const Size(1500, 1100));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final template = fixture(portrait);
        final api = ParityApi(template);
        addTearDown(api.dispose);
        await t.pumpWidget(
          MaterialApp(
            home: CardDesignerScreen(
              schoolUuid: 'school',
              api: api,
              initialTemplate: template,
            ),
          ),
        );
        await t.pumpAndSettle();
        final designerScope = find.byKey(const Key('designer-canvas'));
        final designer = inspect(t, designerScope, template);
        expect(
          find.descendant(
            of: element(designerScope, 'name'),
            matching: find.text('Piyush Kumar Verma'),
          ),
          findsOneWidget,
        );
        await t.pumpWidget(MaterialApp(home: cards(api)));
        await t.pumpAndSettle();
        final preview = find.byType(IdCardPreview);
        final renderer = t.widget<DesignDocumentView>(
          find.descendant(
            of: preview,
            matching: find.byType(DesignDocumentView),
          ),
        );
        expect(renderer.document.toJson(), template.document.toJson());
        expect(renderer.interactive, false);
        final actual = inspect(t, preview, template);
        for (final id in designer.keys) {
          for (var i = 0; i < designer[id]!.length; i++) {
            expect(actual[id]![i], closeTo(designer[id]![i], .000001));
          }
        }
        for (final entry in {
          'school': 'Parity School',
          'address': 'School address',
          'static': 'STUDENT CARD',
          'name': 'Asha Singh',
          'admission': 'ADM-2026',
          'blood': 'B+',
          'class': 'X',
          'section': 'A',
          'custom': 'Blue',
        }.entries) {
          expect(
            find.descendant(
              of: element(preview, entry.key),
              matching: find.text(entry.value),
            ),
            findsOneWidget,
          );
        }
        final photo = t.widget<Image>(
          find.descendant(
            of: element(preview, 'photo'),
            matching: find.byType(Image),
          ),
        );
        expect(
          (photo.image as NetworkImage).url,
          'https://assets.invalid/photo.png',
        );
        final logo = t.widget<Image>(
          find.descendant(
            of: element(preview, 'logo'),
            matching: find.byType(Image),
          ),
        );
        expect(
          (logo.image as NetworkImage).url,
          'https://assets.invalid/logo.png',
        );
        final surface = find
            .descendant(
              of: preview,
              matching: find.byKey(const Key('design-document-surface')),
            )
            .first;
        expect(
          t.getSize(preview).height,
          closeTo(
            t.getSize(surface).height + IdCardPreview.actionsHeight,
            .001,
          ),
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Cards reloads the persisted design after a resultless Designer return',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1500, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final api = ParityApi(fixture(false));
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: cards(api),
          routes: {
            AppRoutes.design: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  api.template = fixture(true);
                  Navigator.pop(context);
                },
                child: const Text('Save portrait and return'),
              ),
            ),
          },
        ),
      );
      await t.pumpAndSettle();
      expect(api.templateReads, 1);
      await t.tap(find.byTooltip('Design card'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save portrait and return'));
      await t.pumpAndSettle();
      expect(api.templateReads, 2);
      final renderer = t.widget<DesignDocumentView>(
        find.byType(DesignDocumentView),
      );
      expect(renderer.document.canvas.width, 53.98);
      expect(renderer.document.canvas.height, 85.6);
      inspect(t, find.byType(IdCardPreview), api.template);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'tight mismatched parent and OS text scale cannot stretch a saved card',
    (t) async {
      final template = fixture(true);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: 500,
                height: 180,
                child: DesignDocumentView(
                  document: template.document,
                  student: actualStudent,
                  schoolProfile: school,
                  assetBaseUrl: 'https://assets.invalid',
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      inspect(t, find.byType(DesignDocumentView), template);
      expect(t.takeException(), isNull);
    },
  );

  test(
    'shared binding rules resolve custom fallback, school and academic fields',
    () {
      const bindings = DesignBindings(
        student: actualStudent,
        schoolProfile: school,
        className: 'X',
        sectionName: 'A',
      );
      final e = fixture(
        true,
      ).document.elements.firstWhere((e) => e.id == 'custom');
      expect(bindings.text(e), 'Blue');
      expect(
        bindings.text(
          e.copyWith(
            data: {
              'field_uuid': 'missing',
              'fallback': 'None',
              'prefix': 'House: ',
            },
          ),
        ),
        'House: None',
      );
      expect(
        bindings.text(
          e.copyWith(
            type: DesignElementType.boundText,
            data: {'field': 'school_address'},
          ),
        ),
        'School address',
      );
    },
  );

  for (final portrait in [true, false]) {
    test(
      'PDF preserves ${portrait ? 'portrait' : 'landscape'} saved page dimensions',
      () async {
        final template = fixture(portrait).copyWith(
          document: fixture(portrait).document.copyWith(
            canvas: DesignCanvas(
              width: portrait ? 53.98 : 85.6,
              height: portrait ? 85.6 : 53.98,
            ),
          ),
        );
        final bytes = await PdfService.generateStudentCard(
          student: actualStudent,
          schoolName: school.schoolName,
          template: template,
          photoUrl: 'invalid-url',
          schoolLogoUrl: 'invalid-url',
          className: 'X',
          sectionName: 'A',
        );
        final source = latin1.decode(bytes, allowInvalid: true);
        final bounds = RegExp(
          r'/MediaBox\s*\[\s*0(?:\.0+)?\s+0(?:\.0+)?\s+([\d.]+)\s+([\d.]+)\s*\]',
        ).firstMatch(source)!;
        expect(
          double.parse(bounds[1]!),
          closeTo(template.document.canvas.width * 72 / 25.4, .01),
        );
        expect(
          double.parse(bounds[2]!),
          closeTo(template.document.canvas.height * 72 / 25.4, .01),
        );
      },
    );
  }
}
