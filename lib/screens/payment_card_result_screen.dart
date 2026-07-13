import 'dart:io';

import 'package:flutter/material.dart';

import '../services/payment_card_parser.dart';

class PaymentCardResultScreen extends StatelessWidget {
  const PaymentCardResultScreen({
    super.key,
    required this.imageFile,
    required this.parsedData,
  });

  final File imageFile;
  final ParsedPaymentCardData parsedData;

  @override
  Widget build(BuildContext context) {
    final found = parsedData.hasCardNumber;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Card Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: Image.file(imageFile, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        found ? Icons.check_circle : Icons.error_outline,
                        color: found ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        found
                            ? '16-digit card number found'
                            : 'Card number not found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  if (found) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      parsedData.formattedCardNumber,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    const Text(
                      'No sequence containing exactly 16 digits was detected. '
                      'Try again with the card number clearly visible.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('View Raw OCR Text'),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  parsedData.rawText.isEmpty
                      ? 'No text detected'
                      : parsedData.rawText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
