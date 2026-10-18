import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../services/content_aware_crop_service.dart';

class ItemCameraScreen extends StatefulWidget {
  const ItemCameraScreen({super.key});

  @override
  State<ItemCameraScreen> createState() => _ItemCameraScreenState();
}

class _ItemCameraScreenState extends State<ItemCameraScreen> {
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
      final cropResult = ContentAwareCropService.crop(bytes);

      if (!cropResult.itemDetected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Item edges were not clear. Original picture was saved. '
              'Use a plain light background for better auto-crop.',
            ),
          ),
        );
      }

      final temporaryDirectory = await getTemporaryDirectory();
      final outputPath = path.join(
        temporaryDirectory.path,
        'cropped_item_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );

      await File(
        outputPath,
      ).writeAsBytes(img.encodeJpg(cropResult.image, quality: 92), flush: true);

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
                  const Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Text(
                      'Place one item on a plain background. The app will detect and crop it automatically.',
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
                  _capturing ? 'AUTO-CROPPING ITEM...' : 'TAKE ITEM PICTURE',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
