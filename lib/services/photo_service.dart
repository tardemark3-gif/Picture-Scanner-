import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/scan_record.dart';
import 'database_service.dart';

class PhotoService {
  PhotoService._();

  static final PhotoService instance = PhotoService._();

  final ImagePicker _imagePicker = ImagePicker();

  String sanitizeBarcode(String barcode) {
    final cleaned = barcode.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

    return cleaned.isEmpty ? 'UNKNOWN_BARCODE' : cleaned;
  }

  Future<Directory> getPictureDirectory() async {
    final applicationDirectory = await getApplicationDocumentsDirectory();

    final pictureDirectory = Directory(
      path.join(applicationDirectory.path, 'BarcodePictures'),
    );

    if (!await pictureDirectory.exists()) {
      await pictureDirectory.create(recursive: true);
    }

    return pictureDirectory;
  }

  Future<ScanRecord?> getExistingRecord(String barcode) async {
    return DatabaseService.instance.getRecordByBarcode(barcode.trim());
  }

  Future<XFile?> takePicture() async {
    return _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
    );
  }

  Future<ScanRecord> saveNewPicture({
    required String barcode,
    required XFile capturedPicture,
  }) async {
    final cleanedBarcode = barcode.trim();

    final existingRecord = await DatabaseService.instance.getRecordByBarcode(
      cleanedBarcode,
    );

    if (existingRecord != null) {
      throw StateError('A picture already exists for barcode $cleanedBarcode.');
    }

    final pictureDirectory = await getPictureDirectory();
    final safeBarcode = sanitizeBarcode(cleanedBarcode);
    final filename = '$safeBarcode.jpg';

    final destinationPath = path.join(pictureDirectory.path, filename);

    final temporaryPath = '$destinationPath.tmp';

    await File(capturedPicture.path).copy(temporaryPath);

    final temporaryFile = File(temporaryPath);
    final destinationFile = File(destinationPath);

    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    await temporaryFile.rename(destinationPath);

    final record = ScanRecord(
      barcode: cleanedBarcode,
      picturePath: destinationPath,
      pictureFilename: filename,
      scannedAt: DateTime.now().toIso8601String(),
    );

    try {
      final insertedId = await DatabaseService.instance.insertRecord(record);

      return ScanRecord(
        id: insertedId,
        barcode: record.barcode,
        picturePath: record.picturePath,
        pictureFilename: record.pictureFilename,
        scannedAt: record.scannedAt,
      );
    } catch (_) {
      if (await destinationFile.exists()) {
        await destinationFile.delete();
      }

      rethrow;
    }
  }

  Future<ScanRecord> replacePicture({
    required ScanRecord existingRecord,
    required XFile capturedPicture,
  }) async {
    final pictureDirectory = await getPictureDirectory();

    final safeBarcode = sanitizeBarcode(existingRecord.barcode);

    final filename = '$safeBarcode.jpg';

    final destinationPath = path.join(pictureDirectory.path, filename);

    final temporaryPath = '$destinationPath.tmp';

    await File(capturedPicture.path).copy(temporaryPath);

    final temporaryFile = File(temporaryPath);
    final destinationFile = File(destinationPath);

    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    await temporaryFile.rename(destinationPath);

    if (existingRecord.picturePath != destinationPath) {
      final previousFile = File(existingRecord.picturePath);

      if (await previousFile.exists()) {
        await previousFile.delete();
      }
    }

    final updatedRecord = ScanRecord(
      id: existingRecord.id,
      barcode: existingRecord.barcode,
      picturePath: destinationPath,
      pictureFilename: filename,
      scannedAt: DateTime.now().toIso8601String(),
    );

    final changedRows = await DatabaseService.instance.replaceRecord(
      updatedRecord,
    );

    if (changedRows != 1) {
      throw StateError('Unable to update the existing barcode record.');
    }

    return updatedRecord;
  }

  Future<void> deletePicture(ScanRecord record) async {
    if (record.id != null) {
      await DatabaseService.instance.deleteRecord(record.id!);
    }

    final pictureFile = File(record.picturePath);

    if (await pictureFile.exists()) {
      await pictureFile.delete();
    }
  }
}
