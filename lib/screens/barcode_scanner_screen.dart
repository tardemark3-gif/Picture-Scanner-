import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState
    extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller =
      MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _accepted = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_accepted) {
      return;
    }

    String? barcodeValue;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();

      if (value != null && value.isNotEmpty) {
        barcodeValue = value;
        break;
      }
    }

    if (barcodeValue == null) {
      return;
    }

    _accepted = true;
    await _controller.stop();

    if (!mounted) {
      return;
    }

    Navigator.pop(context, barcodeValue);
  }

  Future<void> _manualEntry() async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enter Barcode'),
          content: TextField(
            controller: textController,
            autofocus: true,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Barcode',
              hintText: 'Enter barcode number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            onSubmitted: (value) {
              final barcode = value.trim();

              if (barcode.isNotEmpty) {
                Navigator.pop(dialogContext, barcode);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                final barcode = textController.text.trim();

                if (barcode.isNotEmpty) {
                  Navigator.pop(dialogContext, barcode);
                }
              },
              child: const Text('CONTINUE'),
            ),
          ],
        );
      },
    );

    textController.dispose();

    if (!mounted || result == null || result.isEmpty) {
      return;
    }

    _accepted = true;
    await _controller.stop();

    if (!mounted) {
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: const Color(0xFF2948C8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Flashlight',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: const ScannerOverlayPainter(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 38,
            child: Column(
              children: [
                const Text(
                  'Place the barcode inside the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _manualEntry,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black54,
                    side: const BorderSide(
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('ENTER MANUALLY'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  const ScannerOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55);

    final frameWidth =
        size.width > 350 ? 310.0 : size.width - 40;

    const frameHeight = 190.0;

    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          size.width / 2,
          size.height / 2 - 25,
        ),
        width: frameWidth,
        height: frameHeight,
      ),
      const Radius.circular(18),
    );

    final screenPath = Path()
      ..addRect(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      );

    final framePath = Path()..addRRect(frame);

    final overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      framePath,
    );

    canvas.drawPath(overlayPath, overlayPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF69F0AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawRRect(frame, borderPaint);
  }

  @override
  bool shouldRepaint(
    covariant ScannerOverlayPainter oldDelegate,
  ) {
    return false;
  }
}
