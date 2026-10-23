/// Camera barcode scanner — the counterpart of `components/BarcodeScanner.jsx`.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme.dart';

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key, required this.onDetected});

  /// Called once, with the raw barcode value.
  final ValueChanged<String> onDetected;

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.stop();
    if (mounted) Navigator.of(context).pop();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      _handled = true;
      _controller.stop();
      widget.onDetected(raw.trim());
      Navigator.of(context).pop();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'مسح الباركود بالكاميرا',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: _close,
                  child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 420,
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (BuildContext context, MobileScannerException error) {
                return Container(
                  color: AppColors.softDanger,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      _messageFor(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'وجّه الكاميرا نحو الباركود — يُقرأ تلقائياً بدون رفع صور.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  String _messageFor(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'تم رفض إذن الكاميرا. اسمح بالوصول للكاميرا للتطبيق.';
      case MobileScannerErrorCode.unsupported:
        return 'المتصفح لا يدعم الكاميرا. استخدم HTTPS أو localhost.';
      default:
        return 'تعذّر تشغيل الكاميرا: ${error.errorDetails?.message ?? error.errorCode.name}';
    }
  }
}

/// Opens the scanner as a modal dialog and returns the scanned value.
Future<String?> openBarcodeScanner(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => BarcodeScannerSheet(
      onDetected: (String value) => Navigator.of(ctx).pop(value),
    ),
  );
}
