/// Barcode label sheet — the counterpart of the jsPDF block in `pages/Barcodes.jsx`.
///
/// A4 portrait, 3 columns × 8 rows (24 labels per page), exactly like the
/// web version (`cols = 3, rows = 8, cw = 65mm, ch = 33mm`).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/barcode_utils.dart';

const double _mm = PdfPageFormat.mm;

const int kLabelCols = 3;
const int kLabelRows = 8;
const int kLabelsPerPage = kLabelCols * kLabelRows;

/// One label to print.
class BarcodeLabel {
  const BarcodeLabel({required this.name, required this.barcode});

  final String name;
  final String barcode;
}

/// Builds the PDF and opens the system print dialog (share sheet on mobile).
Future<void> printBarcodeSheet(List<BarcodeLabel> labels) async {
  if (labels.isEmpty) return;
  final Uint8List bytes = await buildBarcodePdf(labels);
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: 'barcodes.pdf');
}

/// Builds the A4 label sheet and returns the PDF bytes.
Future<Uint8List> buildBarcodePdf(List<BarcodeLabel> labels) async {
  final pw.Document doc = pw.Document();

  // Product names are Arabic → rendering them with Flutter (which falls back to
  // the platform's Arabic font) and embedding the PNG keeps them readable in
  // the PDF, where the built-in Helvetica has no Arabic glyphs.
  final List<pw.MemoryImage?> names = <pw.MemoryImage?>[];
  for (final BarcodeLabel label in labels) {
    names.add(await _textImage(label.name));
  }

  for (int start = 0; start < labels.length; start += kLabelsPerPage) {
    final int end = (start + kLabelsPerPage).clamp(0, labels.length);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) => pw.Stack(
          children: <pw.Widget>[
            for (int i = start; i < end; i++)
              ..._labelCell(
                index: i - start,
                label: labels[i],
                nameImage: names[i],
              ),
          ],
        ),
      ),
    );
  }

  return doc.save();
}

List<pw.Widget> _labelCell({
  required int index,
  required BarcodeLabel label,
  required pw.MemoryImage? nameImage,
}) {
  final int col = index % kLabelCols;
  final int row = index ~/ kLabelCols;
  final double x = 5 * _mm + col * 65 * _mm;
  final double y = 5 * _mm + row * 33 * _mm;

  final List<pw.Widget> children = <pw.Widget>[];

  if (nameImage != null) {
    children.add(
      pw.Positioned(
        left: x + 2.5 * _mm,
        top: y + 1 * _mm,
        child: pw.SizedBox(
          width: 60 * _mm,
          height: 6 * _mm,
          child: pw.Image(nameImage, fit: pw.BoxFit.contain),
        ),
      ),
    );
  } else {
    children.add(
      pw.Positioned(
        left: x + 2.5 * _mm,
        top: y + 1.5 * _mm,
        child: pw.SizedBox(
          width: 60 * _mm,
          child: pw.Text(
            label.name,
            maxLines: 1,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9),
          ),
        ),
      ),
    );
  }

  children.add(
    pw.Positioned(
      left: x,
      top: y + 7 * _mm,
      child: pw.SizedBox(
        width: 60 * _mm,
        height: 22 * _mm,
        child: pw.BarcodeWidget(
          data: label.barcode,
          barcode: _barcodeFor(label.barcode),
          drawText: true,
          textStyle: pw.TextStyle(fontSize: 8.5),
          textPadding: 1,
        ),
      ),
    ),
  );

  return children;
}

pw.Barcode _barcodeFor(String value) {
  switch (barcodeFormat(value)) {
    case 'EAN13':
      return pw.Barcode.ean13();
    case 'EAN8':
      return pw.Barcode.ean8();
    case 'ITF14':
      return pw.Barcode.itf14();
    default:
      return pw.Barcode.code128();
  }
}

Future<pw.MemoryImage?> _textImage(String text) async {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontSize: 30, color: Colors.black, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.rtl,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: 640);

  final int width = painter.width.ceil().clamp(1, 4096);
  final int height = painter.height.ceil().clamp(1, 4096);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  painter.paint(canvas, Offset.zero);
  painter.dispose();

  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) return null;
  return pw.MemoryImage(data.buffer.asUint8List());
}
