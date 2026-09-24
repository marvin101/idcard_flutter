import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'photo_crop_geometry.dart';

class PhotoDecodeException implements Exception {
  const PhotoDecodeException();

  @override
  String toString() => 'The selected image could not be decoded.';
}

class DecodedPhoto {
  const DecodedPhoto({required this.image, required this.previewBytes});

  final img.Image image;
  final Uint8List previewBytes;

  Size get size => Size(image.width.toDouble(), image.height.toDouble());
}

const int photoCropPreviewMaxDimension = 1280;

Uint8List _encodePreview(img.Image image) {
  final longestSide = math.max(image.width, image.height);
  final preview = longestSide <= photoCropPreviewMaxDimension
      ? image
      : img.copyResize(
          image,
          width: image.width >= image.height
              ? photoCropPreviewMaxDimension
              : null,
          height: image.height > image.width
              ? photoCropPreviewMaxDimension
              : null,
          interpolation: img.Interpolation.linear,
        );
  return Uint8List.fromList(img.encodeJpg(preview, quality: 92));
}

Future<DecodedPhoto> decodeAndNormalizePhoto(XFile file) async {
  final bytes = await file.readAsBytes();
  return decodeAndNormalizePhotoBytes(bytes);
}

DecodedPhoto decodeAndNormalizePhotoBytes(Uint8List bytes) {
  if (bytes.isEmpty) throw const PhotoDecodeException();

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const PhotoDecodeException();
  }
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const PhotoDecodeException();
  }

  try {
    final orientation = decoded.exif.imageIfd.orientation;
    final normalized = orientation == null || orientation == 1
        ? decoded
        : img.bakeOrientation(decoded);
    return DecodedPhoto(
      image: normalized,
      // Full-resolution phone photos can exceed the mobile browser/GPU texture
      // limit and silently paint black. Only the display copy is bounded; the
      // source image below remains full resolution for the saved crop.
      previewBytes: _encodePreview(normalized),
    );
  } catch (_) {
    throw const PhotoDecodeException();
  }
}

class PhotoCropDialog extends StatefulWidget {
  const PhotoCropDialog({super.key, required this.photo});

  final DecodedPhoto photo;

  @override
  State<PhotoCropDialog> createState() => _PhotoCropDialogState();
}

class _PhotoCropDialogState extends State<PhotoCropDialog> {
  late img.Image _image;
  late Uint8List _previewBytes;
  late final ValueNotifier<Rect> _crop;
  PhotoCropMode _mode = PhotoCropMode.free;
  bool _saving = false;
  int _previewRevision = 0;

  Size get _imageSize =>
      Size(_image.width.toDouble(), _image.height.toDouble());

  @override
  void initState() {
    super.initState();
    _image = widget.photo.image;
    _previewBytes = widget.photo.previewBytes;
    _crop = ValueNotifier(PhotoCropGeometry.fullImage(_imageSize));
  }

  @override
  void dispose() {
    _crop.dispose();
    super.dispose();
  }

  void _setMode(PhotoCropMode mode) {
    setState(() {
      _mode = mode;
      _crop.value = PhotoCropGeometry.applyMode(
        crop: _crop.value,
        imageSize: _imageSize,
        mode: mode,
      );
    });
  }

  void _rotate(bool clockwise) {
    final oldHeight = _image.height.toDouble();
    final oldCrop = _crop.value;
    final rotatedCrop = clockwise
        ? Rect.fromLTWH(
            oldHeight - oldCrop.bottom,
            oldCrop.left,
            oldCrop.height,
            oldCrop.width,
          )
        : Rect.fromLTWH(
            oldCrop.top,
            _image.width - oldCrop.right,
            oldCrop.height,
            oldCrop.width,
          );

    setState(() {
      _image = img.copyRotate(_image, angle: clockwise ? 90 : -90);
      _previewBytes = _encodePreview(_image);
      _crop.value = PhotoCropGeometry.clamp(rotatedCrop, _imageSize);
      _previewRevision++;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final bounds = PhotoCropGeometry.clamp(_crop.value, _imageSize);
      final x = bounds.left.floor().clamp(0, _image.width - 1);
      final y = bounds.top.floor().clamp(0, _image.height - 1);
      final width = bounds.width.round().clamp(1, _image.width - x);
      final height = bounds.height.round().clamp(1, _image.height - y);
      final cropped = img.copyCrop(
        _image,
        x: x,
        y: y,
        width: width,
        height: height,
      );
      final bytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
      if (!mounted) return;
      Navigator.of(context).pop(
        XFile.fromData(
          bytes,
          name: 'student_photo.jpg',
          mimeType: 'image/jpeg',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to crop image: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: math.max(320, media.height - 24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Crop Image',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PhotoCropMode.values
                        .map(
                          (mode) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              key: Key('crop-mode-${mode.name}'),
                              label: Text(mode.label),
                              selected: _mode == mode,
                              onSelected: _saving
                                  ? null
                                  : (_) => _setMode(mode),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _ManualCropPreview(
                  key: ValueKey(_previewRevision),
                  bytes: _previewBytes,
                  imageSize: _imageSize,
                  crop: _crop,
                  aspectRatio: _mode.ratioFor(_imageSize),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Drag the box or its corner handles. Pinch, scroll, or drag outside it to inspect the image.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  final rotationButtons = <Widget>[
                    IconButton.outlined(
                      tooltip: 'Rotate left',
                      onPressed: _saving ? null : () => _rotate(false),
                      icon: const Icon(Icons.rotate_left),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Rotate right',
                      onPressed: _saving ? null : () => _rotate(true),
                      icon: const Icon(Icons.rotate_right),
                    ),
                  ];
                  final decisionButtons = <Widget>[
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('save-photo-crop'),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ];

                  if (constraints.maxWidth < 360) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: rotationButtons),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: decisionButtons,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      ...rotationButtons,
                      const Spacer(),
                      ...decisionButtons,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualCropPreview extends StatelessWidget {
  const _ManualCropPreview({
    super.key,
    required this.bytes,
    required this.imageSize,
    required this.crop,
    required this.aspectRatio,
  });

  final Uint8List bytes;
  final Size imageSize;
  final ValueNotifier<Rect> crop;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / imageSize.width,
          constraints.maxHeight / imageSize.height,
        );
        final displaySize = Size(
          imageSize.width * scale,
          imageSize.height * scale,
        );
        return ColoredBox(
          color: Colors.black,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            boundaryMargin: EdgeInsets.all(
              math.max(displaySize.width, displaySize.height),
            ),
            child: Center(
              child: SizedBox.fromSize(
                size: displaySize,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: Image.memory(
                          bytes,
                          key: const Key('crop-preview-image'),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: Color(0xFF2A2A2A),
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(
                                      'This photo cannot be displayed. Please cancel and choose it again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ValueListenableBuilder<Rect>(
                        valueListenable: crop,
                        builder: (context, sourceCrop, child) {
                          final displayCrop = Rect.fromLTWH(
                            sourceCrop.left * scale,
                            sourceCrop.top * scale,
                            sourceCrop.width * scale,
                            sourceCrop.height * scale,
                          );
                          return Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _CropShadePainter(displayCrop),
                                  ),
                                ),
                              ),
                              _CropSelectionOverlay(
                                rect: displayCrop,
                                imageSize: imageSize,
                                displayScale: scale,
                                sourceCrop: sourceCrop,
                                aspectRatio: aspectRatio,
                                onChanged: (value) => crop.value = value,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CropSelectionOverlay extends StatelessWidget {
  const _CropSelectionOverlay({
    required this.rect,
    required this.imageSize,
    required this.displayScale,
    required this.sourceCrop,
    required this.aspectRatio,
    required this.onChanged,
  });

  final Rect rect;
  final Size imageSize;
  final double displayScale;
  final Rect sourceCrop;
  final double? aspectRatio;
  final ValueChanged<Rect> onChanged;

  void _resize(CropHandle handle, DragUpdateDetails details) {
    onChanged(
      PhotoCropGeometry.resize(
        crop: sourceCrop,
        handle: handle,
        delta: details.delta / displayScale,
        imageSize: imageSize,
        aspectRatio: aspectRatio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const handleExtent = 44.0;
    return Positioned.fromRect(
      rect: rect,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('crop-selection'),
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) => onChanged(
                PhotoCropGeometry.move(
                  sourceCrop,
                  details.delta / displayScale,
                  imageSize,
                ),
              ),
              child: CustomPaint(painter: _CropGridPainter()),
            ),
          ),
          for (final entry in <CropHandle, Alignment>{
            CropHandle.topLeft: Alignment.topLeft,
            CropHandle.topRight: Alignment.topRight,
            CropHandle.bottomLeft: Alignment.bottomLeft,
            CropHandle.bottomRight: Alignment.bottomRight,
          }.entries)
            Align(
              alignment: entry.value,
              child: Transform.translate(
                offset: Offset(
                  -entry.value.x * handleExtent / 4,
                  -entry.value.y * handleExtent / 4,
                ),
                child: GestureDetector(
                  key: Key('crop-handle-${entry.key.name}'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => _resize(entry.key, details),
                  child: const SizedBox.square(
                    dimension: handleExtent,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 3),
                          ],
                        ),
                        child: SizedBox.square(dimension: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CropShadePainter extends CustomPainter {
  const _CropShadePainter(this.crop);

  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.58);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, crop.top), paint);
    canvas.drawRect(
      Rect.fromLTRB(0, crop.bottom, size.width, size.height),
      paint,
    );
    canvas.drawRect(Rect.fromLTRB(0, crop.top, crop.left, crop.bottom), paint);
    canvas.drawRect(
      Rect.fromLTRB(crop.right, crop.top, size.width, crop.bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) =>
      oldDelegate.crop != crop;
}

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        line,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        line,
      );
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
