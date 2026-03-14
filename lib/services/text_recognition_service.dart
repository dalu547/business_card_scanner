import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class RecognizedCardText {
  const RecognizedCardText({
    required this.rawText,
    required this.normalizedTextBounds,
  });

  final String rawText;
  final Rect? normalizedTextBounds;
}

class TextRecognitionService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<RecognizedCardText> extractFromFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final imageInfo = await _decodeImage(bytes);
    final recognizedText =
        await _textRecognizer.processImage(InputImage.fromFile(imageFile));

    final rawText = _buildRawText(recognizedText);
    final bounds = _computeTextBounds(recognizedText);
    final normalized = _normalizeRect(
      bounds,
      imageInfo.width.toDouble(),
      imageInfo.height.toDouble(),
    );

    return RecognizedCardText(
      rawText: rawText,
      normalizedTextBounds: normalized,
    );
  }

  Future<Rect?> detectTextBoundsFromCameraImage({
    required CameraImage image,
    required int sensorOrientation,
  }) async {
    final inputImage = _buildInputImage(image, sensorOrientation);
    if (inputImage == null) {
      return null;
    }

    final recognizedText = await _textRecognizer.processImage(inputImage);
    final bounds = _computeTextBounds(recognizedText);
    if (bounds == null || recognizedText.blocks.length < 2) {
      return null;
    }

    final normalized = _normalizeRect(
      bounds,
      image.width.toDouble(),
      image.height.toDouble(),
      sensorOrientation: sensorOrientation,
    );

    if (normalized == null) {
      return null;
    }

    final area = normalized.width * normalized.height;
    if (area < 0.08) {
      return null;
    }

    return normalized;
  }

  InputImage? _buildInputImage(CameraImage image, int sensorOrientation) {
    if (image.planes.isEmpty) return null;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) {
      return null;
    }

    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  String _buildRawText(RecognizedText recognizedText) {
    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }
    return lines.join('\n');
  }

  Rect? _computeTextBounds(RecognizedText recognizedText) {
    Rect? merged;
    for (final block in recognizedText.blocks) {
      final blockRect = block.boundingBox;
      if (blockRect.width <= 0 || blockRect.height <= 0) continue;
      merged = merged == null ? blockRect : merged.expandToInclude(blockRect);
    }
    return merged;
  }

  Rect? _normalizeRect(
    Rect? rect,
    double imageWidth,
    double imageHeight, {
    int sensorOrientation = 0,
  }) {
    if (rect == null || imageWidth <= 0 || imageHeight <= 0) return null;

    Rect normalized;
    if (sensorOrientation == 90) {
      normalized = Rect.fromLTWH(
        rect.top / imageHeight,
        1 - (rect.right / imageWidth),
        rect.height / imageHeight,
        rect.width / imageWidth,
      );
    } else if (sensorOrientation == 270) {
      normalized = Rect.fromLTWH(
        1 - (rect.bottom / imageHeight),
        rect.left / imageWidth,
        rect.height / imageHeight,
        rect.width / imageWidth,
      );
    } else if (sensorOrientation == 180) {
      normalized = Rect.fromLTWH(
        1 - (rect.right / imageWidth),
        1 - (rect.bottom / imageHeight),
        rect.width / imageWidth,
        rect.height / imageHeight,
      );
    } else {
      normalized = Rect.fromLTWH(
        rect.left / imageWidth,
        rect.top / imageHeight,
        rect.width / imageWidth,
        rect.height / imageHeight,
      );
    }

    final left = normalized.left.clamp(0.0, 1.0);
    final top = normalized.top.clamp(0.0, 1.0);
    final right = normalized.right.clamp(0.0, 1.0);
    final bottom = normalized.bottom.clamp(0.0, 1.0);

    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) {
      return null;
    }

    return Rect.fromLTWH(left, top, width, height);
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
