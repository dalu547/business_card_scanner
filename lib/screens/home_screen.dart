import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/card_contact.dart';
import '../services/card_parser.dart';
import '../services/text_recognition_service.dart';
import 'camera_scan_screen.dart';
import 'ocr_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.contacts,
    required this.onSaveContact,
  });

  final List<CardContact> contacts;
  final ValueChanged<CardContact> onSaveContact;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognitionService _textRecognitionService =
      TextRecognitionService();
  bool _busy = false;

  @override
  void dispose() {
    _textRecognitionService.dispose();
    super.dispose();
  }

  Future<void> _scanFromCamera() async {
    final file = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => const CameraScanScreen()),
    );

    if (file == null) return;
    await _scanFile(file);
  }

  Future<void> _pickFromGallery() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null) return;
    await _scanFile(File(picked.path));
  }

  Future<void> _scanFile(File file) async {
    try {
      setState(() => _busy = true);
      final ocr = await _textRecognitionService.extractFromFile(file);
      final parsed = CardParser.parse(ocr.rawText);

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OcrResultScreen(
            imageFile: file,
            parsedData: parsed,
            detectedBounds: ocr.normalizedTextBounds,
            onSave: widget.onSaveContact,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan card: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.contacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Business Card Scanner')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _scanFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Open Camera Scanner'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Import from Gallery'),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: contacts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No contacts yet. Scan a business card to extract structured contact data.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final subtitleParts = <String>[
                        if (contact.designation.isNotEmpty ||
                            contact.company.isNotEmpty)
                          '${contact.designation}${contact.designation.isNotEmpty && contact.company.isNotEmpty ? ' @ ' : ''}${contact.company}',
                        if (contact.mobileNumber.isNotEmpty)
                          contact.mobileNumber,
                        if (contact.email.isNotEmpty) contact.email,
                      ];

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name.characters.first.toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(contact.name.isEmpty
                            ? 'Unknown Name'
                            : contact.name),
                        subtitle: Text(subtitleParts.join('\n')),
                        isThreeLine: subtitleParts.length >= 2,
                        onTap: () => _showContactDetail(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showContactDetail(CardContact contact) {
    final entries = <MapEntry<String, String>>[
      MapEntry('Name', contact.name),
      MapEntry('Designation', contact.designation),
      MapEntry('Company', contact.company),
      MapEntry('Mobile', contact.mobileNumber),
      MapEntry('Secondary Mobile', contact.secondaryMobile),
      MapEntry('Office Phone', contact.officePhone),
      MapEntry('Email', contact.email),
      MapEntry('Website', contact.website),
      MapEntry('Address', contact.address),
      MapEntry('City', contact.city),
      MapEntry('State', contact.state),
      MapEntry('Pincode', contact.pincode),
      MapEntry('Country', contact.country),
      MapEntry('LinkedIn', contact.linkedin),
      MapEntry('Instagram', contact.instagram),
      MapEntry('Twitter', contact.twitter),
      MapEntry('Notes', contact.notes),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                contact.name.isEmpty ? 'Unknown Name' : contact.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...entries.where((entry) => entry.value.trim().isNotEmpty).map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${entry.key}: ${entry.value}'),
                    ),
                  ),
              const SizedBox(height: 8),
              const Text('Raw OCR Text'),
              const SizedBox(height: 6),
              SelectableText(contact.rawText),
            ],
          ),
        ),
      ),
    );
  }
}
