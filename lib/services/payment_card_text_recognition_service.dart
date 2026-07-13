import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class RecognizedPaymentCardText {
  const RecognizedPaymentCardText({
    required this.rawText,
    required this.normalizedTextBounds,
  });

  final String rawText;
  final Rect? normalizedTextBounds;
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

    final lines = <String>[];
    Rect? textBounds;

    for (final block in recognizedText.blocks) {
      if (block.boundingBox.width > 0 && block.boundingBox.height > 0) {
        textBounds = textBounds == null
            ? block.boundingBox
            : textBounds.expandToInclude(block.boundingBox);
      }

      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) lines.add(text);
      }
    }

    return RecognizedPaymentCardText(
      rawText: lines.join('\n'),
      normalizedTextBounds: _normalizeRect(
        textBounds,
        imageInfo.width.toDouble(),
        imageInfo.height.toDouble(),
      ),
    );
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
