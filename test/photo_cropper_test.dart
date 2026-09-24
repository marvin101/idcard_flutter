import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/academic_session.dart';
import 'package:idcard_flutter/models/school_class.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/providers/api_student_form_provider.dart';
import 'package:idcard_flutter/sections/photo_section.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/photo_crop_geometry.dart';
import 'package:idcard_flutter/widgets/photo_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class _PhotoTestApi extends ApiService {
  @override
  Future<List<AcademicSession>> getAcademicSessions(String schoolUuid) async =>
      const [];

  @override
  Future<List<SchoolClass>> getClasses(String schoolUuid) async => const [];

  @override
  Future<List<BuiltinStudentField>> getBuiltinStudentFields(
    String schoolUuid,
  ) async => const [];

  @override
  Future<List<StudentFieldDefinition>> getStudentFields(
    String schoolUuid, {
    bool includeInactive = false,
  }) async => const [];
}

Uint8List _jpeg({int width = 400, int height = 300}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(30, 120, 210));
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  group('photo crop geometry', () {
    const imageSize = Size(1200, 800);
    final full = PhotoCropGeometry.fullImage(imageSize);

    test('defaults can represent the full image in Free mode', () {
      expect(PhotoCropMode.values.first, PhotoCropMode.free);
      expect(PhotoCropMode.free.ratioFor(imageSize), isNull);
      expect(full, const Rect.fromLTWH(0, 0, 1200, 800));
    });

    for (final entry in <PhotoCropMode, double>{
      PhotoCropMode.square: 1,
      PhotoCropMode.threeFour: 3 / 4,
      PhotoCropMode.fourThree: 4 / 3,
      PhotoCropMode.twoThree: 2 / 3,
      PhotoCropMode.original: 1200 / 800,
    }.entries) {
      test('${entry.key.label} applies the expected ratio', () {
        final crop = PhotoCropGeometry.applyMode(
          crop: full,
          imageSize: imageSize,
          mode: entry.key,
        );
        expect(crop.width / crop.height, closeTo(entry.value, 0.000001));
        expect(crop.center, full.center);
        expect(crop.left, greaterThanOrEqualTo(0));
        expect(crop.top, greaterThanOrEqualTo(0));
        expect(crop.right, lessThanOrEqualTo(imageSize.width));
        expect(crop.bottom, lessThanOrEqualTo(imageSize.height));
      });
    }

    test('Free resize changes width and height independently', () {
      final resized = PhotoCropGeometry.resize(
        crop: const Rect.fromLTWH(100, 100, 500, 400),
        handle: CropHandle.bottomRight,
        delta: const Offset(80, -60),
        imageSize: imageSize,
      );
      expect(resized.width, 580);
      expect(resized.height, 340);
    });

    test('move and resize never exceed image bounds', () {
      final moved = PhotoCropGeometry.move(
        const Rect.fromLTWH(100, 100, 500, 400),
        const Offset(5000, -5000),
        imageSize,
      );
      expect(moved, const Rect.fromLTWH(700, 0, 500, 400));

      final resized = PhotoCropGeometry.resize(
        crop: const Rect.fromLTWH(200, 200, 300, 300),
        handle: CropHandle.bottomRight,
        delta: const Offset(5000, 5000),
        imageSize: imageSize,
        aspectRatio: 1,
      );
      expect(resized.right, lessThanOrEqualTo(imageSize.width));
      expect(resized.bottom, lessThanOrEqualTo(imageSize.height));
      expect(resized.width / resized.height, closeTo(1, 0.000001));
    });
  });

  group('photo decoding', () {
    test('empty and invalid bytes fail gracefully', () {
      expect(
        () => decodeAndNormalizePhotoBytes(Uint8List(0)),
        throwsA(isA<PhotoDecodeException>()),
      );
      expect(
        () => decodeAndNormalizePhotoBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<PhotoDecodeException>()),
      );
    });

    test('valid bytes decode and retain their full dimensions', () {
      final decoded = decodeAndNormalizePhotoBytes(
        _jpeg(width: 320, height: 180),
      );
      expect(decoded.size, const Size(320, 180));
      expect(decoded.previewBytes, isNotEmpty);
    });
  });

  testWidgets('crop dialog starts in Free with the full image selected', (
    tester,
  ) async {
    final photo = decodeAndNormalizePhotoBytes(_jpeg());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PhotoCropDialog(photo: photo)),
      ),
    );
    await tester.pumpAndSettle();

    final freeChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('crop-mode-free')),
    );
    expect(freeChip.selected, isTrue);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('3:4'), findsOneWidget);
    expect(find.text('4:3'), findsOneWidget);
    expect(find.text('2:3'), findsOneWidget);

    final imageRect = tester.getRect(
      find.byKey(const Key('crop-preview-image')),
    );
    final cropRect = tester.getRect(find.byKey(const Key('crop-selection')));
    expect(cropRect, imageRect);
  });

  testWidgets('crop dialog controls remain reachable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final photo = decodeAndNormalizePhotoBytes(_jpeg());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PhotoCropDialog(photo: photo)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save-photo-crop')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid gallery and camera images reach the shared cropper', (
    tester,
  ) async {
    final provider = ApiStudentFormProvider(
      api: _PhotoTestApi(),
      schoolUuid: 'school-1',
    );
    final sources = <ImageSource>[];
    var cropCalls = 0;
    final output = XFile.fromData(
      _jpeg(width: 100, height: 100),
      name: 'crop.jpg',
      mimeType: 'image/jpeg',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: PhotoSection(
              photoPicker: (context, source) async {
                sources.add(source);
                return XFile.fromData(_jpeg(), name: 'source.jpg');
              },
              photoCropper: (context, photo) async {
                cropCalls++;
                expect(photo.size, const Size(400, 300));
                return output;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('take-student-photo')));
    await tester.pumpAndSettle();
    expect(sources, [ImageSource.camera]);
    expect(cropCalls, 1);
    expect(provider.selectedPhoto, same(output));

    await tester.tap(find.byKey(const Key('upload-student-photo')));
    await tester.pumpAndSettle();
    expect(sources, [ImageSource.camera, ImageSource.gallery]);
    expect(cropCalls, 2);

    await tester.tap(find.byKey(const Key('remove-student-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove-student-photo')));
    await tester.pumpAndSettle();
    expect(provider.selectedPhoto, isNull);
    provider.dispose();
  });

  testWidgets('invalid selected bytes show an error and skip the cropper', (
    tester,
  ) async {
    final provider = ApiStudentFormProvider(
      api: _PhotoTestApi(),
      schoolUuid: 'school-1',
    );
    var cropCalls = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: PhotoSection(
              photoPicker: (context, source) async =>
                  XFile.fromData(Uint8List(0)),
              photoCropper: (context, photo) async {
                cropCalls++;
                return null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('take-student-photo')));
    await tester.pump();
    expect(cropCalls, 0);
    expect(
      find.text(
        'The captured photo could not be read. Please retake the photo or upload one instead.',
      ),
      findsOneWidget,
    );
    provider.dispose();
  });
}
