import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class RecognizedPaymentCardText {
  const RecognizedPaymentCardText({
    required this.rawText,
    required this.alternativeRawTexts,
    required this.normalizedTextBounds,
  });

  final String rawText;
  final List<String> alternativeRawTexts;
  final Rect? normalizedTextBounds;

  Iterable<String> get allRawTexts sync* {
    yield rawText;
    yield* alternativeRawTexts;
  }
}

class PaymentCardTextRecognitionService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<RecognizedPaymentCardText> extractFromFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final imageInfo = await _decodeImage(bytes);
    final recognizedText =
        await _textRecognizer.processImage(InputImage.fromFile(imageFile));

    final lines = _extractLines(recognizedText);
    Rect? textBounds;

    for (final block in recognizedText.blocks) {
      if (block.boundingBox.width > 0 && block.boundingBox.height > 0) {
        textBounds = textBounds == null
            ? block.boundingBox
            : textBounds.expandToInclude(block.boundingBox);
      }
    }

    final alternativeRawTexts = await _recognizeEnhancedNumberBand(
      sourceImage: imageInfo,
      recognizedText: recognizedText,
    );

    return RecognizedPaymentCardText(
      rawText: lines.join('\n'),
      alternativeRawTexts: alternativeRawTexts,
      normalizedTextBounds: _normalizeRect(
        textBounds,
        imageInfo.width.toDouble(),
        imageInfo.height.toDouble(),
      ),
    );
  }

  List<String> _extractLines(RecognizedText recognizedText) {
    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) lines.add(text);
      }
    }
    return lines;
  }

  Future<List<String>> _recognizeEnhancedNumberBand({
    required ui.Image sourceImage,
    required RecognizedText recognizedText,
  }) async {
    TextLine? bestLine;
    var bestDigitCount = 0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final digitCount = RegExp(r'\d').allMatches(line.text).length;
        if (digitCount > bestDigitCount) {
          bestLine = line;
          bestDigitCount = digitCount;
        }
      }
    }

    // A payment-card line should already expose a meaningful run of digits.
    // Below this threshold, a crop is more likely to target an expiry date.
    if (bestLine == null || bestDigitCount < 7) return const [];

    final band = _expandedNumberBand(
      bestLine.boundingBox,
      sourceImage.width.toDouble(),
      sourceImage.height.toDouble(),
    );
    if (band == null) return const [];

    final results = <String>[];
    final generatedFiles = <File>[];

    try {
      for (final grayscale in [false, true]) {
        final processed = await _renderNumberBand(
          sourceImage,
          band,
          grayscale: grayscale,
        );
        final bytes =
            await processed.toByteData(format: ui.ImageByteFormat.png);
        processed.dispose();
        if (bytes == null) continue;

        final suffix = grayscale ? 'contrast' : 'color';
        final file = File(
          '${Directory.systemTemp.path}/payment_card_${DateTime.now().microsecondsSinceEpoch}_$suffix.png',
        );
        generatedFiles.add(file);
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

        final retried =
            await _textRecognizer.processImage(InputImage.fromFile(file));
        final rawText = _extractLines(retried).join('\n').trim();
        if (rawText.isNotEmpty && !results.contains(rawText)) {
          results.add(rawText);
        }
      }
    } finally {
      for (final file in generatedFiles) {
        if (await file.exists()) await file.delete();
      }
    }

    return results;
  }

  Rect? _expandedNumberBand(Rect line, double width, double height) {
    if (line.width <= 0 || line.height <= 0) return null;

    // ML Kit may recognize only the first groups. Expand farther to the right
    // so omitted final groups are included in the retry.
    final left = (line.left - line.width * 0.2).clamp(0.0, width);
    final right = (line.right + line.width * 0.9).clamp(0.0, width);
    final top = (line.top - line.height * 1.2).clamp(0.0, height);
    final bottom = (line.bottom + line.height * 1.2).clamp(0.0, height);
    if (right <= left || bottom <= top) return null;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<ui.Image> _renderNumberBand(
    ui.Image source,
    Rect sourceRect, {
    required bool grayscale,
  }) {
    final scale = (1800 / sourceRect.width).clamp(1.5, 3.0);
    final outputWidth = (sourceRect.width * scale).round();
    final outputHeight = (sourceRect.height * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final destination = Rect.fromLTWH(
      0,
      0,
      outputWidth.toDouble(),
      outputHeight.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.high;

    if (grayscale) {
      const contrast = 1.7;
      const offset = 128 * (1 - contrast);
      paint.colorFilter = const ColorFilter.matrix([
        0.2126 * contrast,
        0.7152 * contrast,
        0.0722 * contrast,
        0,
        offset,
        0.2126 * contrast,
        0.7152 * contrast,
        0.0722 * contrast,
        0,
        offset,
        0.2126 * contrast,
        0.7152 * contrast,
        0.0722 * contrast,
        0,
        offset,
        0,
        0,
        0,
        1,
        0,
      ]);
    }

    canvas.drawImageRect(source, sourceRect, destination, paint);
    return recorder.endRecording().toImage(outputWidth, outputHeight);
  }

  Rect? _normalizeRect(Rect? rect, double width, double height) {
    if (rect == null || width <= 0 || height <= 0) return null;

    final left = (rect.left / width).clamp(0.0, 1.0);
    final top = (rect.top / height).clamp(0.0, 1.0);
    final right = (rect.right / width).clamp(0.0, 1.0);
    final bottom = (rect.bottom / height).clamp(0.0, 1.0);
    if (right <= left || bottom <= top) return null;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<ui.Image> _decodeImage(List<int> bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(Uint8List.fromList(bytes), completer.complete);
    return completer.future;
  }

  Future<void> dispose() => _textRecognizer.close();
}
