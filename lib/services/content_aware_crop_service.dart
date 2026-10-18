import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class AutoCropResult {
  final img.Image image;
  final bool itemDetected;
  final double confidence;

  const AutoCropResult({
    required this.image,
    required this.itemDetected,
    required this.confidence,
  });
}

class ContentAwareCropService {
  ContentAwareCropService._();

  static AutoCropResult crop(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('The captured picture could not be processed.');
    }

    final source = img.bakeOrientation(decoded);
    final width = source.width;
    final height = source.height;

    if (width < 40 || height < 40) {
      return AutoCropResult(image: source, itemDetected: false, confidence: 0);
    }

    final sampleStep = math.max(2, math.min(width, height) ~/ 320);
    final borderSize = math.max(4, math.min(width, height) ~/ 25);
    final background = _estimateBackground(
      source,
      borderSize: borderSize,
      step: sampleStep,
    );

    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;
    var foregroundSamples = 0;
    var totalSamples = 0;

    for (var y = borderSize; y < height - borderSize; y += sampleStep) {
      for (var x = borderSize; x < width - borderSize; x += sampleStep) {
        totalSamples++;
        final pixel = source.getPixel(x, y);
        if (!_isForeground(pixel, background)) {
          continue;
        }

        foregroundSamples++;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }

    if (maxX < minX || maxY < minY || foregroundSamples == 0) {
      return AutoCropResult(image: source, itemDetected: false, confidence: 0);
    }

    final rawWidth = maxX - minX + sampleStep;
    final rawHeight = maxY - minY + sampleStep;
    final boxAreaRatio = (rawWidth * rawHeight) / (width * height);
    final foregroundRatio = foregroundSamples / math.max(1, totalSamples);

    final cropIsTooSmall = boxAreaRatio < 0.025;
    final foregroundIsTooWeak = foregroundRatio < 0.008;
    final cropIsAlmostFullImage = boxAreaRatio > 0.88;

    if (cropIsTooSmall || foregroundIsTooWeak || cropIsAlmostFullImage) {
      return AutoCropResult(
        image: source,
        itemDetected: false,
        confidence: foregroundRatio,
      );
    }

    final marginX = math.max(12, (rawWidth * 0.08).round());
    final marginY = math.max(12, (rawHeight * 0.08).round());

    final cropX = math.max(0, minX - marginX);
    final cropY = math.max(0, minY - marginY);
    final cropRight = math.min(width, maxX + sampleStep + marginX);
    final cropBottom = math.min(height, maxY + sampleStep + marginY);
    final cropWidth = math.max(1, cropRight - cropX);
    final cropHeight = math.max(1, cropBottom - cropY);

    final cropped = img.copyCrop(
      source,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    final confidence = math.min(
      1.0,
      foregroundRatio * 3.5 + math.min(boxAreaRatio, 0.5),
    );

    return AutoCropResult(
      image: cropped,
      itemDetected: true,
      confidence: confidence,
    );
  }

  static _Rgb _estimateBackground(
    img.Image image, {
    required int borderSize,
    required int step,
  }) {
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var count = 0;

    void addPixel(int x, int y) {
      final pixel = image.getPixel(x, y);
      red += pixel.r.toDouble();
      green += pixel.g.toDouble();
      blue += pixel.b.toDouble();
      count++;
    }

    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < borderSize; x += step) {
        addPixel(x, y);
        addPixel(image.width - 1 - x, y);
      }
    }

    for (var x = borderSize; x < image.width - borderSize; x += step) {
      for (var y = 0; y < borderSize; y += step) {
        addPixel(x, y);
        addPixel(x, image.height - 1 - y);
      }
    }

    return _Rgb(
      red / math.max(1, count),
      green / math.max(1, count),
      blue / math.max(1, count),
    );
  }

  static bool _isForeground(img.Pixel pixel, _Rgb background) {
    final red = pixel.r.toDouble();
    final green = pixel.g.toDouble();
    final blue = pixel.b.toDouble();

    final dr = red - background.red;
    final dg = green - background.green;
    final db = blue - background.blue;
    final colorDistance = math.sqrt(dr * dr + dg * dg + db * db);

    final luminance = 0.299 * red + 0.587 * green + 0.114 * blue;
    final backgroundLuminance =
        0.299 * background.red +
        0.587 * background.green +
        0.114 * background.blue;
    final darkerBy = backgroundLuminance - luminance;

    final maxChannel = math.max(red, math.max(green, blue));
    final minChannel = math.min(red, math.min(green, blue));
    final chroma = maxChannel - minChannel;

    final lightBackground = backgroundLuminance >= 175;

    if (lightBackground) {
      final stronglyColored = chroma >= 32;
      final veryDarkDetail = darkerBy >= 92;
      final coloredDifference = colorDistance >= 72 && chroma >= 18;

      return stronglyColored || veryDarkDetail || coloredDifference;
    }

    final stronglyColored = chroma >= 44;
    final strongDifference = colorDistance >= 78;
    final veryDarkDetail = luminance <= 72;

    return stronglyColored || strongDifference || veryDarkDetail;
  }
}

class _Rgb {
  final double red;
  final double green;
  final double blue;

  const _Rgb(this.red, this.green, this.blue);
}
