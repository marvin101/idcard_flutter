import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/api_student_form_provider.dart';
import '../widgets/photo_cropper.dart';
import '../widgets/photo_source_picker.dart';

typedef StudentPhotoPicker = Future<XFile?> Function(BuildContext, ImageSource);
typedef StudentPhotoCropper =
    Future<XFile?> Function(BuildContext, DecodedPhoto);

class PhotoSection extends StatelessWidget {
  const PhotoSection({super.key, this.photoPicker, this.photoCropper});

  final StudentPhotoPicker? photoPicker;
  final StudentPhotoCropper? photoCropper;

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiStudentFormProvider>(
      builder: (context, provider, _) {
        final localPhoto = provider.selectedPhoto;
        final existingPhotoUrl = provider.existingPhotoUrl;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Photo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _buildPhotoPreview(
                    localPhoto: localPhoto,
                    existingPhotoUrl: existingPhotoUrl,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('upload-student-photo'),
                      onPressed: provider.saving
                          ? null
                          : () => _selectPhoto(
                              context,
                              provider,
                              ImageSource.gallery,
                            ),
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        localPhoto != null || existingPhotoUrl != null
                            ? 'Change Photo'
                            : 'Upload Photo',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('take-student-photo'),
                      onPressed: provider.saving
                          ? null
                          : () => _selectPhoto(
                              context,
                              provider,
                              ImageSource.camera,
                            ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take Photo'),
                    ),
                    if (localPhoto != null || existingPhotoUrl != null)
                      OutlinedButton.icon(
                        key: const Key('remove-student-photo'),
                        onPressed: provider.saving
                            ? null
                            : () => _confirmRemovePhoto(context, provider),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoPreview({
    required XFile? localPhoto,
    required String? existingPhotoUrl,
  }) {
    if (localPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<Uint8List>(
          future: localPhoto.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 52,
                  color: Colors.grey,
                ),
              );
            }
            return Image.memory(
              snapshot.data!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 52,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
      );
    }

    if (existingPhotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          existingPhotoUrl,
          width: double.infinity,
          height: 180,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 52,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_camera, size: 52, color: Colors.grey),
          SizedBox(height: 12),
          Text('Upload a student photo', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _confirmRemovePhoto(
    BuildContext context,
    ApiStudentFormProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student photo?'),
        content: const Text(
          'The stored photo will be permanently removed when you save the student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-remove-student-photo'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) provider.removePhoto();
  }

  Future<void> _selectPhoto(
    BuildContext context,
    ApiStudentFormProvider provider,
    ImageSource source,
  ) async {
    final image = await (photoPicker ?? pickPhotoFromSource)(context, source);
    if (image == null || !context.mounted) return;

    late final DecodedPhoto decoded;
    try {
      decoded = await decodeAndNormalizePhoto(image);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The captured photo could not be read. Please retake the photo or upload one instead.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final croppedPhoto = await (photoCropper ?? _showCropper)(context, decoded);
    if (croppedPhoto == null || !context.mounted) return;
    provider.setSelectedPhoto(croppedPhoto);
  }

  Future<XFile?> _showCropper(BuildContext context, DecodedPhoto photo) {
    return showDialog<XFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PhotoCropDialog(photo: photo),
    );
  }
}
