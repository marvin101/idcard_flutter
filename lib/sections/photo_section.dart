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

typedef StudentPhotoDecoder = Future<DecodedPhoto> Function(XFile);

class PhotoSection extends StatelessWidget {
  const PhotoSection({
    super.key,
    this.photoPicker,
    this.photoCropper,
    this.photoDecoder,
  });

  final StudentPhotoPicker? photoPicker;
  final StudentPhotoCropper? photoCropper;
  final StudentPhotoDecoder? photoDecoder;

  static const double _mobileBreakpoint = 700;

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiStudentFormProvider>(
      builder: (context, provider, _) {
        final localPhoto = provider.selectedPhoto;
        final existingPhotoUrl = provider.existingPhotoUrl;

        final hasPhoto = localPhoto != null || existingPhotoUrl != null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _mobileBreakpoint;

            final theme = Theme.of(context);

            return Card(
              margin: EdgeInsets.zero,
              elevation: compact ? 0 : 3,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(compact ? 14 : 20),
                side: compact
                    ? BorderSide(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.20,
                        ),
                      )
                    : BorderSide.none,
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student photo',
                      style: compact
                          ? theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            )
                          : theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                    ),

                    SizedBox(height: compact ? 4 : 6),

                    Text(
                      hasPhoto
                          ? 'Review or replace the student photo.'
                          : 'Add a clear photo for the ID card.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    SizedBox(height: compact ? 14 : 24),

                    _PhotoPreview(
                      localPhoto: localPhoto,
                      existingPhotoUrl: existingPhotoUrl,
                      compact: compact,
                    ),

                    SizedBox(height: compact ? 14 : 20),

                    _PhotoActions(
                      compact: compact,
                      saving: provider.saving,
                      hasPhoto: hasPhoto,
                      onUpload: () =>
                          _selectPhoto(context, provider, ImageSource.gallery),
                      onCamera: () =>
                          _selectPhoto(context, provider, ImageSource.camera),
                      onRemove: () => _confirmRemovePhoto(context, provider),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-remove-student-photo'),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.removePhoto();
    }
  }

  Future<void> _selectPhoto(
    BuildContext context,
    ApiStudentFormProvider provider,
    ImageSource source,
  ) async {
    final image = await (photoPicker ?? pickPhotoFromSource)(context, source);

    if (image == null || !context.mounted) {
      return;
    }

    late final DecodedPhoto decoded;

    try {
      final prepared = await showDialog<DecodedPhoto>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PhotoPreparingDialog(
          imageFile: image,
          decoder: photoDecoder ?? decodeAndNormalizePhoto,
        ),
      );

      if (prepared == null) {
        throw const PhotoDecodeException();
      }

      decoded = prepared;
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

    if (!context.mounted) {
      return;
    }

    final croppedPhoto = await (photoCropper ?? _showCropper)(context, decoded);

    if (croppedPhoto == null || !context.mounted) {
      return;
    }

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

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.localPhoto,
    required this.existingPhotoUrl,
    required this.compact,
  });

  final XFile? localPhoto;
  final String? existingPhotoUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final height = compact ? 142.0 : 180.0;

    return Semantics(
      image: localPhoto != null || existingPhotoUrl != null,
      label: localPhoto != null || existingPhotoUrl != null
          ? 'Student photo preview'
          : 'No student photo selected',
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.28),
          ),
        ),
        child: _buildContent(context, height),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double height) {
    final theme = Theme.of(context);

    if (localPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        child: FutureBuilder<Uint8List>(
          future: localPhoto!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _brokenImage();
            }

            return Image.memory(
              snapshot.data!,
              width: double.infinity,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _brokenImage(),
            );
          },
        ),
      );
    }

    if (existingPhotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        child: Image.network(
          existingPhotoUrl!,
          width: double.infinity,
          height: height,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }

            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) => _brokenImage(),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: compact ? 36 : 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              'No photo selected',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Upload a photo or use the camera.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brokenImage() {
    return const Center(
      child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
    );
  }
}

class _PhotoActions extends StatelessWidget {
  const _PhotoActions({
    required this.compact,
    required this.saving,
    required this.hasPhoto,
    required this.onUpload,
    required this.onCamera,
    required this.onRemove,
  });

  final bool compact;
  final bool saving;
  final bool hasPhoto;

  final VoidCallback onUpload;
  final VoidCallback onCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _uploadButton(),
          _cameraButton(),
          if (hasPhoto) _removeButton(),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 320;

        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fullWidth(_uploadButton()),
              const SizedBox(height: 10),
              _fullWidth(_cameraButton()),
              if (hasPhoto) ...[
                const SizedBox(height: 10),
                _fullWidth(_removeButton()),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _uploadButton()),
                const SizedBox(width: 10),
                Expanded(child: _cameraButton()),
              ],
            ),
            if (hasPhoto) ...[
              const SizedBox(height: 10),
              _fullWidth(_removeButton()),
            ],
          ],
        );
      },
    );
  }

  Widget _fullWidth(Widget child) {
    return SizedBox(width: double.infinity, child: child);
  }

  Widget _uploadButton() {
    return OutlinedButton.icon(
      key: const Key('upload-student-photo'),
      onPressed: saving ? null : onUpload,
      icon: const Icon(Icons.upload_file_outlined),
      label: Text(hasPhoto ? 'Change' : 'Upload'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _cameraButton() {
    return OutlinedButton.icon(
      key: const Key('take-student-photo'),
      onPressed: saving ? null : onCamera,
      icon: const Icon(Icons.photo_camera_outlined),
      label: const Text('Camera'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _removeButton() {
    return OutlinedButton.icon(
      key: const Key('remove-student-photo'),
      onPressed: saving ? null : onRemove,
      icon: const Icon(Icons.delete_outline),
      label: const Text('Remove photo'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _PhotoPreparingDialog extends StatefulWidget {
  const _PhotoPreparingDialog({required this.imageFile, required this.decoder});

  final XFile imageFile;
  final StudentPhotoDecoder decoder;

  @override
  State<_PhotoPreparingDialog> createState() => _PhotoPreparingDialogState();
}

class _PhotoPreparingDialogState extends State<_PhotoPreparingDialog> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    // Let the progress UI reach the screen before CPU-heavy image decoding
    // begins on Flutter Web's main thread.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final photo = await widget.decoder(widget.imageFile);

      if (mounted) {
        Navigator.of(context).pop(photo);
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Flexible(child: Text('Preparing photo…')),
        ],
      ),
    );
  }
}
