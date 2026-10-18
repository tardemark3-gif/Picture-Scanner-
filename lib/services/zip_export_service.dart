import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import '../models/scan_record.dart';
import 'excel_export_service.dart';

class ZipExportService {
  ZipExportService._();

  static final ZipExportService instance = ZipExportService._();

  Future<String> createAndShareZip(List<ScanRecord> records) async {
    if (records.isEmpty) {
      throw StateError('There are no records to export.');
    }

    final excelPath = await ExcelExportService.instance.createWorkbook(records);

    final exportDirectory = await ExcelExportService.instance
        .getExportDirectory();

    final zipPath = path.join(
      exportDirectory.path,
      'Picture_Scanner_Export_'
      '${ExcelExportService.instance.createTimestamp()}.zip',
    );

    final encoder = ZipFileEncoder();

    encoder.create(zipPath);

    try {
      await encoder.addFile(File(excelPath), 'Barcode_Picture_Report.xlsx');

      for (final record in records) {
        final pictureFile = File(record.picturePath);

        if (!await pictureFile.exists()) {
          continue;
        }

        await encoder.addFile(
          pictureFile,
          path.join('Pictures', record.pictureFilename),
        );
      }
    } finally {
      await encoder.close();
    }

    await SharePlus.instance.share(
      ShareParams(
        subject: 'Picture Scanner ZIP Export',
        text:
            'Excel report and barcode pictures '
            'exported from Picture Scanner.',
        files: [XFile(zipPath, mimeType: 'application/zip')],
      ),
    );

    return zipPath;
  }
}
