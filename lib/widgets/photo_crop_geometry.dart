import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum PhotoCropMode { free, original, square, threeFour, fourThree, twoThree }

extension PhotoCropModeDetails on PhotoCropMode {
  String get label => switch (this) {
    PhotoCropMode.free => 'Free',
    PhotoCropMode.original => 'Original',
    PhotoCropMode.square => '1:1',
    PhotoCropMode.threeFour => '3:4',
    PhotoCropMode.fourThree => '4:3',
    PhotoCropMode.twoThree => '2:3',
  };

  double? ratioFor(Size imageSize) => switch (this) {
    PhotoCropMode.free => null,
    PhotoCropMode.original => imageSize.width / imageSize.height,
    PhotoCropMode.square => 1,
    PhotoCropMode.threeFour => 3 / 4,
    PhotoCropMode.fourThree => 4 / 3,
    PhotoCropMode.twoThree => 2 / 3,
  };
}

enum CropHandle { topLeft, topRight, bottomLeft, bottomRight }

class PhotoCropGeometry {
  const PhotoCropGeometry._();

  static Rect fullImage(Size imageSize) => Offset.zero & imageSize;

  static Rect applyMode({
    required Rect crop,
    required Size imageSize,
    required PhotoCropMode mode,
  }) {
    final ratio = mode.ratioFor(imageSize);
    if (ratio == null) return clamp(crop, imageSize);

    final center = Offset(
      crop.center.dx.clamp(0.0, imageSize.width),
      crop.center.dy.clamp(0.0, imageSize.height),
    );
    final maxWidth = 2.0 * math.min(center.dx, imageSize.width - center.dx);
    final maxHeight = 2.0 * math.min(center.dy, imageSize.height - center.dy);

    double width = maxWidth;
    double height = width / ratio;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }

    return Rect.fromCenter(center: center, width: width, height: height);
  }

  static Rect move(Rect crop, Offset delta, Size imageSize) {
    final dx = delta.dx.clamp(-crop.left, imageSize.width - crop.right);
    final dy = delta.dy.clamp(-crop.top, imageSize.height - crop.bottom);
    return crop.shift(Offset(dx, dy));
  }

  static Rect resize({
    required Rect crop,
    required CropHandle handle,
    required Offset delta,
    required Size imageSize,
    double? aspectRatio,
    double minSize = 32,
  }) {
    final anchor = switch (handle) {
      CropHandle.topLeft => crop.bottomRight,
      CropHandle.topRight => crop.bottomLeft,
      CropHandle.bottomLeft => crop.topRight,
      CropHandle.bottomRight => crop.topLeft,
    };
    final originalCorner = switch (handle) {
      CropHandle.topLeft => crop.topLeft,
      CropHandle.topRight => crop.topRight,
      CropHandle.bottomLeft => crop.bottomLeft,
      CropHandle.bottomRight => crop.bottomRight,
    };
    final signX = originalCorner.dx < anchor.dx ? -1.0 : 1.0;
    final signY = originalCorner.dy < anchor.dy ? -1.0 : 1.0;
    var width = ((originalCorner.dx + delta.dx) - anchor.dx).abs();
    var height = ((originalCorner.dy + delta.dy) - anchor.dy).abs();

    final maxWidth = signX < 0 ? anchor.dx : imageSize.width - anchor.dx;
    final maxHeight = signY < 0 ? anchor.dy : imageSize.height - anchor.dy;

    if (aspectRatio == null) {
      width = width.clamp(math.min(minSize, maxWidth), maxWidth);
      height = height.clamp(math.min(minSize, maxHeight), maxHeight);
    } else {
      if (width / math.max(height, 0.001) > aspectRatio) {
        height = width / aspectRatio;
      } else {
        width = height * aspectRatio;
      }
      final scale = math.min(
        1.0,
        math.min(maxWidth / width, maxHeight / height),
      );
      width *= scale;
      height *= scale;
      final minimumWidth = math.min(minSize, maxWidth);
      final minimumHeight = math.min(minSize / aspectRatio, maxHeight);
      if (width < minimumWidth || height < minimumHeight) {
        width = math.min(
          maxWidth,
          math.max(minimumWidth, minimumHeight * aspectRatio),
        );
        height = width / aspectRatio;
        if (height > maxHeight) {
          height = maxHeight;
          width = height * aspectRatio;
        }
      }
    }

    final corner = Offset(
      anchor.dx + signX * width,
      anchor.dy + signY * height,
    );
    return Rect.fromPoints(anchor, corner);
  }

  static Rect clamp(Rect crop, Size imageSize) {
    final width = crop.width.clamp(0.0, imageSize.width);
    final height = crop.height.clamp(0.0, imageSize.height);
    final left = crop.left.clamp(0.0, imageSize.width - width);
    final top = crop.top.clamp(0.0, imageSize.height - height);
    return Rect.fromLTWH(left, top, width, height);
  }
}
