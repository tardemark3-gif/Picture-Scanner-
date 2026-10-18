import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../services/photo_service.dart';
import '../services/zip_export_service.dart';
import 'barcode_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScanRecord> _records = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await DatabaseService.instance.getRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _scanBarcode() async {
    if (_busy) return;
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final cleanedBarcode = barcode.trim();
      final existing = await PhotoService.instance.getExistingRecord(
        cleanedBarcode,
      );

      if (!mounted) return;

      if (existing != null) {
        final replace = await _showReplaceDialog(existing);
        if (!mounted || replace != true) return;

        final captured = await PhotoService.instance.takePicture();
        if (!mounted || captured == null) {
          _showMessage('Picture capture was cancelled.');
          return;
        }

        final updated = await PhotoService.instance.replacePicture(
          existingRecord: existing,
          capturedPicture: captured,
        );
        await _loadRecords();
        if (mounted) {
          _showMessage(
            'Picture replaced: ${updated.pictureFilename}',
            success: true,
          );
        }
        return;
      }

      final captured = await PhotoService.instance.takePicture();
      if (!mounted || captured == null) {
        _showMessage('Picture capture was cancelled.');
        return;
      }

      final saved = await PhotoService.instance.saveNewPicture(
        barcode: cleanedBarcode,
        capturedPicture: captured,
      );
      await _loadRecords();
      if (mounted) {
        _showMessage('Saved: ${saved.pictureFilename}', success: true);
      }
    } catch (error) {
      if (mounted) _showMessage('Operation failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showReplaceDialog(ScanRecord record) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFF59E0B),
          size: 42,
        ),
        title: const Text('Barcode Already Exists'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A picture is already saved for this barcode.'),
            const SizedBox(height: 14),
            Text(
              'Barcode: ${record.barcode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Existing picture: ${record.pictureFilename}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('REPLACE PICTURE'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(ScanRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete picture?'),
        content: Text(
          'Delete ${record.pictureFilename} and remove barcode '
          '${record.barcode} from the list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await PhotoService.instance.deletePicture(record);
      await _loadRecords();
      if (mounted) _showMessage('Picture deleted.');
    } catch (error) {
      if (mounted) _showMessage('Delete failed: $error', error: true);
    }
  }

  Future<void> _exportExcel() async {
    if (_busy) return;
    if (_records.isEmpty) {
      _showMessage('There are no records to export.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ZipExportService.instance.createAndShareZip(
        _records.reversed.toList(),
      );
      if (mounted) {
        _showMessage('ZIP with Excel and pictures created.', success: true);
      }
    } catch (error) {
      if (mounted) _showMessage('Export failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(
    String message, {
    bool success = false,
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? Colors.red.shade700
            : success
            ? Colors.green.shade700
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Picture Scanner',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'One barcode, one picture',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _loadRecords,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadRecords, child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _scanBarcode,
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_scanner),
        label: Text(_busy ? 'PROCESSING' : 'SCAN BARCODE'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _busy || _records.isEmpty ? null : _exportExcel,
            icon: const Icon(Icons.file_download_outlined),
            label: Text('EXPORT ${_records.length} RECORDS TO ZIP'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.photo_camera_outlined,
            size: 92,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            'No barcode pictures yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap SCAN BARCODE, scan an item, then take one picture. '
            'Scanning the same barcode again offers Replace Picture.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        final imageFile = File(record.picturePath);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: SizedBox(
              width: 70,
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: imageFile.existsSync()
                    ? Image.file(imageFile, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
              ),
            ),
            title: Text(
              record.barcode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  record.pictureFilename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  ExcelExportService.instance.formatDateTime(record.scannedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            trailing: IconButton(
              tooltip: 'Delete',
              onPressed: _busy ? null : () => _deleteRecord(record),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}
