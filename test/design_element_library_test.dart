import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_element_library.dart';
import 'package:idcard_flutter/models/design_geometry.dart';

void main() {
  const canvas = DesignCanvas(width: 85.6, height: 53.98);

  test(
    'stable library has one deterministic definition for every wire type',
    () {
      expect(
        DesignElementLibrary.definitions.map((item) => item.type).toSet(),
        DesignElementType.values.toSet(),
      );
      expect(
        DesignElementLibrary.definitions,
        hasLength(DesignElementType.values.length),
      );
      for (final type in DesignElementType.values) {
        final first = DesignElementLibrary.create(
          type: type,
          id: 'first',
          zIndex: 1,
          canvas: canvas,
          customFieldUuid: type == DesignElementType.customFieldText
              ? 'field-id'
              : null,
          customFieldLabel: type == DesignElementType.customFieldText
              ? 'House'
              : null,
        );
        final second = DesignElementLibrary.create(
          type: type,
          id: 'second',
          zIndex: 2,
          canvas: canvas,
          customFieldUuid: type == DesignElementType.customFieldText
              ? 'field-id'
              : null,
          customFieldLabel: type == DesignElementType.customFieldText
              ? 'House'
              : null,
        );
        expect(first.type, type);
        expect(first.style, second.style);
        expect(first.data, second.data);
        expect(validateElementGeometry(first, canvas), isEmpty);
      }
    },
  );

  test('identity defaults are scoped without mutating catalog values', () {
    final student = DesignElementLibrary.create(
      type: DesignElementType.barcode,
      id: 'student',
      zIndex: 0,
      canvas: canvas,
    );
    final personnel = DesignElementLibrary.create(
      type: DesignElementType.barcode,
      id: 'personnel',
      zIndex: 1,
      canvas: canvas,
      identityType: 'personnel',
    );
    expect(student.data['field'], 'admission_no');
    expect(personnel.data['field'], 'employee_no');
    expect(
      DesignElementLibrary.definition(DesignElementType.barcode).data['field'],
      'admission_no',
    );
  });

  test('elements that cannot satisfy their contract reject a tiny canvas', () {
    const tiny = DesignCanvas(width: 11, height: 11);
    expect(
      DesignElementLibrary.fitsCanvas(DesignElementType.qrCode, tiny),
      false,
    );
    expect(
      () => DesignElementLibrary.create(
        type: DesignElementType.qrCode,
        id: 'qr',
        zIndex: 0,
        canvas: tiny,
      ),
      throwsArgumentError,
    );
  });

  test('QR and Data Matrix stay square and above backend minimums', () {
    var qr = DesignElementLibrary.create(
      type: DesignElementType.qrCode,
      id: 'qr',
      zIndex: 0,
      canvas: canvas,
    );
    qr = setElementSize(qr, canvas, width: 5);
    expect((qr.width, qr.height), (12, 12));
    qr = resizeElementFromHandle(qr, canvas, 'bottom-right', -20, -20);
    expect((qr.width, qr.height), (12, 12));

    var matrix =
        DesignElementLibrary.create(
          type: DesignElementType.barcode,
          id: 'matrix',
          zIndex: 1,
          canvas: canvas,
        ).copyWith(
          width: 20,
          height: 20,
          data: const {'symbology': 'data_matrix', 'text': 'ID-1'},
        );
    matrix = setElementSize(matrix, canvas, height: 8);
    expect((matrix.width, matrix.height), (12, 12));
  });

  test('one-dimensional barcode cannot be resized below 25 by 10 mm', () {
    var barcode = DesignElementLibrary.create(
      type: DesignElementType.barcode,
      id: 'barcode',
      zIndex: 0,
      canvas: canvas,
    );
    barcode = setElementSize(barcode, canvas, width: 2);
    barcode = setElementSize(barcode, canvas, height: 1);
    expect((barcode.width, barcode.height), (25, 10));
  });

  test('alignment uses exact physical canvas edges and centres', () {
    final source = DesignElementLibrary.create(
      type: DesignElementType.rectangle,
      id: 'shape',
      zIndex: 0,
      canvas: canvas,
    );
    expect(
      alignElementToCanvas(source, canvas, CanvasElementAlignment.left).x,
      0,
    );
    expect(
      alignElementToCanvas(
        source,
        canvas,
        CanvasElementAlignment.horizontalCenter,
      ).x,
      (canvas.width - source.width) / 2,
    );
    expect(
      alignElementToCanvas(source, canvas, CanvasElementAlignment.bottom).y,
      canvas.height - source.height,
    );
  });
}
