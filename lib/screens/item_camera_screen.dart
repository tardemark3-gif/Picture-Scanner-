import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/manual_crop_service.dart';

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
      final manuallyCropped = await ManualCropService.instance.cropPicture(
        sourcePath: captured.path,
      );

      if (manuallyCropped == null) {
        if (mounted) {
          setState(() {
            _capturing = false;
          });
        }
        return;
      }

      final outputPath = manuallyCropped.path;

      final capturedFile = File(captured.path);

      if (capturedFile.path != outputPath && await capturedFile.exists()) {
        await capturedFile.delete();
      }

      if (!mounted) {
        return;
      }

      final activeController = _controller;

      setState(() {
        _controller = null;
      });

      if (activeController != null) {
        await activeController.dispose();
      }

      if (!mounted) {
        return;
      }

      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(XFile(outputPath));
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
    final controller = _controller;
    _controller = null;
    controller?.dispose();
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

    final controller = _controller;

    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
                      'Take the full product picture, then adjust the crop box around the item.',
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
                  _capturing ? 'OPENING CROP EDITOR...' : 'TAKE ITEM PICTURE',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
