import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/payment_card_parser.dart';
import '../services/payment_card_text_recognition_service.dart';
import 'camera_scan_screen.dart';
import 'payment_card_result_screen.dart';

class PaymentCardScannerTab extends StatefulWidget {
  const PaymentCardScannerTab({super.key});

  @override
  State<PaymentCardScannerTab> createState() => _PaymentCardScannerTabState();
}

class _PaymentCardScannerTabState extends State<PaymentCardScannerTab> {
  final ImagePicker _picker = ImagePicker();
  final PaymentCardTextRecognitionService _recognitionService =
      PaymentCardTextRecognitionService();
  bool _busy = false;

  @override
  void dispose() {
    _recognitionService.dispose();
    super.dispose();
  }

  Future<void> _scanFromCamera() async {
    final file = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => const CameraScanScreen()),
    );
    if (file != null) await _scanFile(file);
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked != null) await _scanFile(File(picked.path));
  }

  Future<void> _scanFile(File file) async {
    try {
      setState(() => _busy = true);
      final recognized = await _recognitionService.extractFromFile(file);
      final parsed = PaymentCardParser.parse(recognized.rawText);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentCardResultScreen(
            imageFile: file,
            parsedData: parsed,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan payment card: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.credit_card,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Credit / Debit Card Scanner',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Scan the front of a card. A result is accepted when a 16-digit '
          'card number is detected.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _scanFromCamera,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Open Camera Scanner'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickFromGallery,
          icon: const Icon(Icons.photo_library),
          label: const Text('Import from Gallery'),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}
