import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveDownloadedFile({
  required Uint8List bytes,
  required String filename,
  required String contentType,
}) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Save student import template',
    fileName: filename,
    bytes: bytes,
  );
}
