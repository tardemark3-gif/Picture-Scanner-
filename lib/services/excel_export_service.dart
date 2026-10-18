import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/scan_record.dart';

class ExcelExportService {
  ExcelExportService._();

  static final ExcelExportService instance = ExcelExportService._();

  String formatDateTime(String value) {
    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }

    final local = parsed.toLocal();

    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour24 = local.hour;
    final hour12 = hour24 == 0
        ? 12
        : hour24 > 12
        ? hour24 - 12
        : hour24;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';

    return '$month/$day/${local.year} '
        '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  String createTimestamp() {
    final now = DateTime.now();

    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Future<Directory> getExportDirectory() async {
    final applicationDirectory = await getApplicationDocumentsDirectory();

    final exportDirectory = Directory(
      path.join(applicationDirectory.path, 'Exports'),
    );

    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    return exportDirectory;
  }

  Future<String> createWorkbook(List<ScanRecord> records) async {
    if (records.isEmpty) {
      throw StateError('There are no records to export.');
    }

    final workbook = Excel.createExcel();
    final sheet = workbook['Barcode Pictures'];

    sheet.appendRow([
      TextCellValue('No.'),
      TextCellValue('Barcode'),
      TextCellValue('Picture Filename'),
      TextCellValue('Picture Path'),
      TextCellValue('Date Scanned'),
    ]);

    for (var index = 0; index < records.length; index++) {
      final record = records[index];

      sheet.appendRow([
        IntCellValue(index + 1),
        TextCellValue(record.barcode),
        TextCellValue(record.pictureFilename),
        TextCellValue(record.picturePath),
        TextCellValue(formatDateTime(record.scannedAt)),
      ]);
    }

    if (workbook.tables.containsKey('Sheet1')) {
      workbook.delete('Sheet1');
    }

    final workbookBytes = workbook.encode();

    if (workbookBytes == null) {
      throw StateError('Unable to generate the Excel workbook.');
    }

    final exportDirectory = await getExportDirectory();

    final exportPath = path.join(
      exportDirectory.path,
      'Barcode_Picture_Report_${createTimestamp()}.xlsx',
    );

    await File(
      exportPath,
    ).writeAsBytes(Uint8List.fromList(workbookBytes), flush: true);

    return exportPath;
  }

  Future<String> exportAndShare(List<ScanRecord> records) async {
    final exportPath = await createWorkbook(records);

    await SharePlus.instance.share(
      ShareParams(
        subject: 'Barcode Picture Report',
        text:
            'Barcode and picture report exported '
            'from Picture Scanner.',
        files: [
          XFile(
            exportPath,
            mimeType:
                'application/vnd.openxmlformats-officedocument.'
                'spreadsheetml.sheet',
          ),
        ],
      ),
    );

    return exportPath;
  }
}
