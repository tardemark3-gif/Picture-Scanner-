import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ItemCameraScreen extends StatefulWidget {
  const ItemCameraScreen({super.key});

  @override
  State<ItemCameraScreen> createState() => _ItemCameraScreenState();
}

class _ItemCameraScreenState extends State<ItemCameraScreen> {
  static const double _cropWidthRatio = 0.88;
  static const double _cropHeightRatio = 0.68;

  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _captureAndCrop() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }

    setState(() => _capturing = true);

    try {
      final captured = await controller.takePicture();
      final bytes = await File(captured.path).readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw StateError('The captured picture could not be processed.');
      }

      final oriented = img.bakeOrientation(decoded);
      final cropWidth = math.max(1, (oriented.width * _cropWidthRatio).round());
      final cropHeight = math.max(
        1,
        (oriented.height * _cropHeightRatio).round(),
      );
      final cropX = math.max(0, ((oriented.width - cropWidth) / 2).round());
      final cropY = math.max(0, ((oriented.height - cropHeight) / 2).round());

      final cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      final temporaryDirectory = await getTemporaryDirectory();
      final outputPath = path.join(
        temporaryDirectory.path,
        'cropped_item_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );

      await File(
        outputPath,
      ).writeAsBytes(img.encodeJpg(cropped, quality: 92), flush: true);

      final capturedFile = File(captured.path);
      if (await capturedFile.exists()) {
        await capturedFile.delete();
      }

      if (!mounted) return;
      Navigator.pop(context, XFile(outputPath));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Picture capture failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Item Picture'),
        backgroundColor: const Color(0xFF2948C8),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final controller = _controller!;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / controller.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  const IgnorePointer(child: ItemCropOverlay()),
                  const Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Text(
                      'Fill the box with the item. Only the area inside the box will be saved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _capturing ? null : _captureAndCrop,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _capturing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _capturing ? 'CROPPING ITEM...' : 'TAKE ITEM PICTURE',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ItemCropOverlay extends StatelessWidget {
  const ItemCropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: ItemCropOverlayPainter());
  }
}

class ItemCropOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * _ItemCameraScreenState._cropWidthRatio,
        height: size.height * _ItemCameraScreenState._cropHeightRatio,
      ),
      const Radius.circular(18),
    );

    final background = Path()..addRect(Offset.zero & size);
    final opening = Path()..addRRect(frame);
    final shaded = Path.combine(PathOperation.difference, background, opening);

    canvas.drawPath(
      shaded,
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );

    canvas.drawRRect(
      frame,
      Paint()
        ..color = const Color(0xFF69F0AE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
