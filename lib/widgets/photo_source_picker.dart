import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Uses the same picker for gallery and camera. Camera failures leave the
/// gallery action available, including when browser permission is denied.
Future<XFile?> pickPhotoFromSource(
  BuildContext context,
  ImageSource source, {
  Future<XFile?> Function()? galleryOverride,
}) async {
  try {
    return source == ImageSource.gallery && galleryOverride != null
        ? await galleryOverride()
        : await ImagePicker().pickImage(source: source);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera unavailable or permission denied. You can upload a photo instead.'
                : 'Could not open photos. Please try again.',
          ),
        ),
      );
    }
    return null;
  }
}
