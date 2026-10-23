/// Live barcode preview — the counterpart of `components/BarcodePreview.jsx`.
library;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../core/barcode_utils.dart';
import '../core/theme.dart';

/// Maps a barcode string to the symbology used by the React app
/// (EAN-13 / EAN-8 / ITF-14, otherwise CODE128).
Barcode barcodeFor(String code) {
  switch (barcodeFormat(code)) {
    case 'EAN13':
      return Barcode.ean13();
    case 'EAN8':
      return Barcode.ean8();
    case 'ITF14':
      return Barcode.itf14();
    default:
      return Barcode.code128();
  }
}

class BarcodePreview extends StatelessWidget {
  const BarcodePreview({super.key, required this.value, this.height = 64});

  final String value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final String code = value.trim();
    if (code.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.softGrey,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: <Widget>[
            const Text(
              'سيظهر شكل الباركود هنا',
              style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            const Text(
              'امسح بالكاميرا أو اكتب الرقم',
              style: TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: <Widget>[
          BarcodeWidget(
            barcode: barcodeFor(code),
            data: code,
            height: height,
            drawText: true,
            backgroundColor: Colors.white,
            color: AppColors.ink,
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
            errorBuilder: (BuildContext context, String error) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'تعذّر عرض هذا الباركود',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            code,
            style: const TextStyle(fontSize: 12, color: AppColors.muted, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
