import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/text_recognition_service.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  static const Rect _guideRect = Rect.fromLTWH(0.08, 0.33, 0.84, 0.34);

  CameraController? _controller;
  final TextRecognitionService _textRecognitionService =
      TextRecognitionService();

  bool _initializing = true;
  bool _capturing = false;
  bool _processingFrame = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  Rect? _detectedBounds;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera found');
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );

      await controller.initialize();
      await controller.startImageStream(_processFrame);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start camera')),
      );
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (_processingFrame) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameAt).inMilliseconds < 450) return;

    _processingFrame = true;
    _lastFrameAt = now;

    try {
      final bounds =
          await _textRecognitionService.detectTextBoundsFromCameraImage(
        image: image,
        sensorOrientation: controller.description.sensorOrientation,
      );

      if (!mounted) return;
      setState(() {
        _detectedBounds = bounds;
      });
    } catch (_) {
      // Ignore frame-level errors and keep streaming.
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }

    try {
      setState(() => _capturing = true);
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      final photo = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(photo.path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture image')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final cardDetected = _isCardInsideGuide(_detectedBounds);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Card')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : controller == null || !controller.value.isInitialized
              ? const Center(child: Text('Camera unavailable'))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    CustomPaint(
                      painter: _CardBoundsPainter(
                        guideRect: _guideRect,
                        cardDetected: cardDetected,
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 32,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              cardDetected
                                  ? 'Card detected in frame'
                                  : _detectedBounds == null
                                      ? 'Align the card in frame'
                                      : 'Move card into guide box',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _capturing ? null : _capture,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Capture Card'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  bool _isCardInsideGuide(Rect? detectedBounds) {
    if (detectedBounds == null) {
      return false;
    }

    final intersection = detectedBounds.intersect(_guideRect);
    if (intersection.width <= 0 || intersection.height <= 0) {
      return false;
    }

    final detectedArea = detectedBounds.width * detectedBounds.height;
    if (detectedArea <= 0) {
      return false;
    }

    final overlapRatio =
        (intersection.width * intersection.height) / detectedArea;
    return overlapRatio >= 0.5;
  }
}

class _CardBoundsPainter extends CustomPainter {
  const _CardBoundsPainter({
    required this.guideRect,
    required this.cardDetected,
  });

  final Rect guideRect;
  final bool cardDetected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      guideRect.left * size.width,
      guideRect.top * size.height,
      guideRect.width * size.width,
      guideRect.height * size.height,
    );
    final color = cardDetected ? Colors.lightGreenAccent : Colors.amberAccent;

    final fillPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.fill;

    final clear = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    final overlay = Path.combine(PathOperation.difference, clear, hole);
    canvas.drawPath(overlay, fillPaint);

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CardBoundsPainter oldDelegate) {
    return oldDelegate.guideRect != guideRect ||
        oldDelegate.cardDetected != cardDetected;
  }
}
