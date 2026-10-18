import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ManualCropService {
  ManualCropService._();

  static final ManualCropService instance = ManualCropService._();

  Future<XFile?> cropPicture({required String sourcePath}) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 94,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Product Crop',
          toolbarColor: const Color(0xFF2948C8),
          toolbarWidgetColor: Colors.white,
          statusBarLight: false,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: const Color(0xFF69F0AE),
          cropFrameColor: const Color(0xFF69F0AE),
          cropGridColor: Colors.white70,
          dimmedLayerColor: Colors.black87,
          showCropGrid: true,
          hideBottomControls: false,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (croppedFile == null) {
      return null;
    }

    return XFile(croppedFile.path);
  }
}
