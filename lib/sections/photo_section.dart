import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/api_student_form_provider.dart';

class PhotoSection extends StatelessWidget {
  const PhotoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiStudentFormProvider>(
      builder: (context, provider, _) {
        final photo = provider.selectedPhoto;

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
                  child: photo == null
                      ? const _EmptyPhotoPreview()
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FutureBuilder<Uint8List>(
                            future: photo.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
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
                              );
                            },
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.saving
                        ? null
                        : () => _selectPhoto(context, provider),
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      photo == null ? 'Upload Photo' : 'Change Photo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectPhoto(
    BuildContext context,
    ApiStudentFormProvider provider,
  ) async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null || !context.mounted) {
      return;
    }

    final XFile? croppedPhoto = await showDialog<XFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PhotoCropDialog(imageFile: image),
    );

    if (croppedPhoto == null || !context.mounted) {
      return;
    }

    provider.setSelectedPhoto(croppedPhoto);
  }
}

class _EmptyPhotoPreview extends StatelessWidget {
  const _EmptyPhotoPreview();

  @override
  Widget build(BuildContext context) {
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
}

// ============================================================
// CUSTOM PHOTO CROP DIALOG
// ============================================================

class _PhotoCropDialog extends StatefulWidget {
  const _PhotoCropDialog({required this.imageFile});

  final XFile imageFile;

  @override
  State<_PhotoCropDialog> createState() => _PhotoCropDialogState();
}

class _PhotoCropDialogState extends State<_PhotoCropDialog> {
  Uint8List? _bytes;

  double _zoom = 1.0;
  double _angle = 0.0;

  Offset _offset = Offset.zero;
  Offset _dragStart = Offset.zero;
  Offset _offsetStart = Offset.zero;

  bool _loading = true;
  bool _saving = false;

  // 3:4 is the preferred ID-card portrait ratio.
  double _aspectRatio = 3 / 4;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      Navigator.of(context).pop();
    }
  }

  void _setAspectRatio(double ratio) {
    setState(() {
      _aspectRatio = ratio;
      _offset = Offset.zero;
    });
  }

  void _rotateLeft() {
    setState(() {
      _angle -= math.pi / 2;
    });
  }

  void _rotateRight() {
    setState(() {
      _angle += math.pi / 2;
    });
  }

  Future<void> _saveCrop() async {
    if (_bytes == null || _saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final croppedBytes = await _cropImage();

      if (!mounted) return;

      final croppedFile = XFile.fromData(
        croppedBytes,
        name: 'student_photo.jpg',
        mimeType: 'image/jpeg',
      );

      Navigator.of(context).pop(croppedFile);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to crop image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List> _cropImage() async {
    final original = img.decodeImage(_bytes!);

    if (original == null) {
      throw Exception('Unable to read the selected image.');
    }

    img.Image working = original;

    if (_angle != 0) {
      working = img.copyRotate(
        working,
        angle: (_angle * 180 / math.pi).round(),
      );
    }

    final width = working.width;
    final height = working.height;

    double cropWidth;
    double cropHeight;

    if (width / height > _aspectRatio) {
      cropHeight = height.toDouble();
      cropWidth = cropHeight * _aspectRatio;
    } else {
      cropWidth = width.toDouble();
      cropHeight = cropWidth / _aspectRatio;
    }

    cropWidth /= _zoom;
    cropHeight /= _zoom;

    final centerX = width / 2 + _offset.dx * width / 500;
    final centerY = height / 2 + _offset.dy * height / 500;

    int left = (centerX - cropWidth / 2).round();
    int top = (centerY - cropHeight / 2).round();

    int finalWidth = cropWidth.round();
    int finalHeight = cropHeight.round();

    left = left.clamp(0, math.max(0, width - finalWidth));
    top = top.clamp(0, math.max(0, height - finalHeight));

    finalWidth = math.min(finalWidth, width - left);
    finalHeight = math.min(finalHeight, height - top);

    final cropped = img.copyCrop(
      working,
      x: left,
      y: top,
      width: finalWidth,
      height: finalHeight,
    );

    final encoded = img.encodeJpg(cropped, quality: 92);

    return Uint8List.fromList(encoded);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: _loading
            ? const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            : _buildDialogContent(),
      ),
    );
  }

  Widget _buildDialogContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----------------------------------------------------
          // Header
          // ----------------------------------------------------
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Crop Image',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),

              IconButton(
                tooltip: 'Close',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ----------------------------------------------------
          // Aspect ratio buttons
          // ----------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RatioButton(
                label: '1:1',
                selected: _aspectRatio == 1,
                onPressed: () => _setAspectRatio(1),
              ),

              const SizedBox(width: 8),

              _RatioButton(
                label: '3:4',
                selected: _aspectRatio == 3 / 4,
                onPressed: () => _setAspectRatio(3 / 4),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // Crop preview
          // ----------------------------------------------------
          Flexible(
            child: _CropPreview(
              bytes: _bytes!,
              aspectRatio: _aspectRatio,
              zoom: _zoom,
              offset: _offset,
              angle: _angle,
              onPanStart: (details) {
                _dragStart = details.localPosition;
                _offsetStart = _offset;
              },
              onPanUpdate: (details) {
                final delta = details.localPosition - _dragStart;

                setState(() {
                  _offset = Offset(
                    _offsetStart.dx + delta.dx,
                    _offsetStart.dy + delta.dy,
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 18),

          // ----------------------------------------------------
          // Zoom
          // ----------------------------------------------------
          _SliderRow(
            label: 'Zoom',
            value: _zoom,
            min: 1,
            max: 3,
            onChanged: (value) {
              setState(() {
                _zoom = value;
              });
            },
          ),

          const SizedBox(height: 8),

          // ----------------------------------------------------
          // Angle
          // ----------------------------------------------------
          _SliderRow(
            label: 'Angle',
            value: _angle,
            min: -math.pi / 4,
            max: math.pi / 4,
            displayValue: '${(_angle * 180 / math.pi).round()}°',
            onChanged: (value) {
              setState(() {
                _angle = value;
              });
            },
          ),

          const SizedBox(height: 8),

          // ----------------------------------------------------
          // Rotate buttons
          // ----------------------------------------------------
          Row(
            children: [
              const SizedBox(
                width: 55,
                child: Text(
                  'Rotate',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),

              IconButton.outlined(
                tooltip: 'Rotate left',
                onPressed: _saving ? null : _rotateLeft,
                icon: const Icon(Icons.rotate_left),
              ),

              const SizedBox(width: 8),

              IconButton.outlined(
                tooltip: 'Rotate right',
                onPressed: _saving ? null : _rotateRight,
                icon: const Icon(Icons.rotate_right),
              ),

              const Spacer(),

              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),

              const SizedBox(width: 8),

              FilledButton(
                onPressed: _saving ? null : _saveCrop,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CROP PREVIEW
// ============================================================

class _CropPreview extends StatelessWidget {
  const _CropPreview({
    required this.bytes,
    required this.aspectRatio,
    required this.zoom,
    required this.offset,
    required this.angle,
    required this.onPanStart,
    required this.onPanUpdate,
  });

  final Uint8List bytes;
  final double aspectRatio;
  final double zoom;
  final Offset offset;
  final double angle;

  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        double width = maxWidth;
        double height = width / aspectRatio;

        if (height > maxHeight) {
          height = maxHeight;
          width = height * aspectRatio;
        }

        return Center(
          child: GestureDetector(
            onPanStart: onPanStart,
            onPanUpdate: onPanUpdate,
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black),

                    Transform.translate(
                      offset: offset,
                      child: Transform.rotate(
                        angle: angle,
                        child: Transform.scale(
                          scale: zoom,
                          child: Image.memory(bytes, fit: BoxFit.cover),
                        ),
                      ),
                    ),

                    IgnorePointer(
                      child: CustomPaint(painter: _CropGridPainter()),
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

class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    final vertical1 = size.width / 3;
    final vertical2 = size.width * 2 / 3;

    final horizontal1 = size.height / 3;
    final horizontal2 = size.height * 2 / 3;

    canvas.drawLine(
      Offset(vertical1, 0),
      Offset(vertical1, size.height),
      paint,
    );

    canvas.drawLine(
      Offset(vertical2, 0),
      Offset(vertical2, size.height),
      paint,
    );

    canvas.drawLine(
      Offset(0, horizontal1),
      Offset(size.width, horizontal1),
      paint,
    );

    canvas.drawLine(
      Offset(0, horizontal2),
      Offset(size.width, horizontal2),
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ============================================================
// RATIO BUTTON
// ============================================================

class _RatioButton extends StatelessWidget {
  const _RatioButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Colors.blue : null,
        foregroundColor: selected ? Colors.white : Colors.black87,
        side: BorderSide(color: selected ? Colors.blue : Colors.grey.shade400),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

// ============================================================
// SLIDER ROW
// ============================================================

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.displayValue,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String? displayValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),

        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),

        SizedBox(
          width: 45,
          child: Text(
            displayValue ??
                (label == 'Zoom'
                    ? value.toStringAsFixed(1)
                    : value.toStringAsFixed(1)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
