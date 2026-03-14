import 'dart:io';

import 'package:flutter/material.dart';

import '../models/card_contact.dart';
import '../services/card_parser.dart';

class OcrResultScreen extends StatefulWidget {
  const OcrResultScreen({
    super.key,
    required this.imageFile,
    required this.parsedData,
    required this.detectedBounds,
    required this.onSave,
  });

  final File imageFile;
  final ParsedCardData parsedData;
  final Rect? detectedBounds;
  final ValueChanged<CardContact> onSave;

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _designationController;
  late final TextEditingController _companyController;
  late final TextEditingController _mobileController;
  late final TextEditingController _secondaryMobileController;
  late final TextEditingController _officePhoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _countryController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _instagramController;
  late final TextEditingController _twitterController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final p = widget.parsedData;
    _nameController = TextEditingController(text: p.name);
    _designationController = TextEditingController(text: p.designation);
    _companyController = TextEditingController(text: p.company);
    _mobileController = TextEditingController(text: p.mobileNumber);
    _secondaryMobileController = TextEditingController(text: p.secondaryMobile);
    _officePhoneController = TextEditingController(text: p.officePhone);
    _emailController = TextEditingController(text: p.email);
    _websiteController = TextEditingController(text: p.website);
    _addressController = TextEditingController(text: p.address);
    _cityController = TextEditingController(text: p.city);
    _stateController = TextEditingController(text: p.state);
    _pincodeController = TextEditingController(text: p.pincode);
    _countryController = TextEditingController(text: p.country);
    _linkedinController = TextEditingController(text: p.linkedin);
    _instagramController = TextEditingController(text: p.instagram);
    _twitterController = TextEditingController(text: p.twitter);
    _notesController = TextEditingController(text: p.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _companyController.dispose();
    _mobileController.dispose();
    _secondaryMobileController.dispose();
    _officePhoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    _linkedinController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(
      CardContact(
        name: _nameController.text.trim(),
        designation: _designationController.text.trim(),
        company: _companyController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        secondaryMobile: _secondaryMobileController.text.trim(),
        officePhone: _officePhoneController.text.trim(),
        email: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        country: _countryController.text.trim(),
        linkedin: _linkedinController.text.trim(),
        instagram: _instagramController.text.trim(),
        twitter: _twitterController.text.trim(),
        notes: _notesController.text.trim(),
        rawText: widget.parsedData.rawText,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact saved to list')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Extracted Data')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(widget.imageFile, fit: BoxFit.cover),
                    if (widget.detectedBounds != null)
                      CustomPaint(
                          painter: _DetectedBoundsPainter(
                              bounds: widget.detectedBounds!)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _field(_nameController, 'Name'),
            _field(_designationController, 'Designation'),
            _field(_companyController, 'Company'),
            _field(_mobileController, 'Mobile Number',
                keyboardType: TextInputType.phone),
            _field(_secondaryMobileController, 'Secondary Mobile',
                keyboardType: TextInputType.phone),
            _field(_officePhoneController, 'Office Phone',
                keyboardType: TextInputType.phone),
            _field(_emailController, 'Email',
                keyboardType: TextInputType.emailAddress),
            _field(_websiteController, 'Website',
                keyboardType: TextInputType.url),
            _field(_addressController, 'Address', minLines: 2, maxLines: 4),
            _field(_cityController, 'City'),
            _field(_stateController, 'State'),
            _field(_pincodeController, 'Pincode',
                keyboardType: TextInputType.number),
            _field(_countryController, 'Country'),
            _field(_linkedinController, 'LinkedIn',
                keyboardType: TextInputType.url),
            _field(_instagramController, 'Instagram',
                keyboardType: TextInputType.url),
            _field(_twitterController, 'Twitter',
                keyboardType: TextInputType.url),
            _field(_notesController, 'Notes', minLines: 2, maxLines: 4),
            const SizedBox(height: 16),
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
                  child: SelectableText(widget.parsedData.rawText),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _DetectedBoundsPainter extends CustomPainter {
  const _DetectedBoundsPainter({required this.bounds});

  final Rect bounds;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      bounds.left * size.width,
      bounds.top * size.height,
      bounds.width * size.width,
      bounds.height * size.height,
    );

    final fill = Paint()
      ..color = Colors.black38
      ..style = PaintingStyle.fill;

    final all = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    final overlay = Path.combine(PathOperation.difference, all, hole);
    canvas.drawPath(overlay, fill);

    final stroke = Paint()
      ..color = Colors.lightGreenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)), stroke);
  }

  @override
  bool shouldRepaint(covariant _DetectedBoundsPainter oldDelegate) {
    return oldDelegate.bounds != bounds;
  }
}
