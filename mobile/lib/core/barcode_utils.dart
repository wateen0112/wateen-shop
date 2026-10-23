/// Barcode helpers — mirrors `backend/barcode.js` and `frontend/src/lib/barcode.js`.
library;

/// Removes spaces and dashes.
String normalizeBarcode(Object? code) =>
    (code ?? '').toString().replaceAll(RegExp(r'[\s-]'), '');

/// GTIN check digit: weights 3,1,3,1… from the right.
int gtinCheckDigit(String payload) {
  var sum = 0;
  var mult = 3;
  for (var i = payload.length - 1; i >= 0; i--) {
    sum += int.parse(payload[i]) * mult;
    mult = mult == 3 ? 1 : 3;
  }
  return (10 - (sum % 10)) % 10;
}

/// A barcode is valid when it is all digits, has a known length (8/12/13/14)
/// and the GTIN check digit matches.
bool isValidBarcode(Object? code) {
  final d = normalizeBarcode(code);
  if (!<int>[8, 12, 13, 14].contains(d.length)) return false;
  if (!RegExp(r'^\d+$').hasMatch(d)) return false;
  return gtinCheckDigit(d.substring(0, d.length - 1)) == int.parse(d[d.length - 1]);
}

/// Display symbology for a valid barcode, otherwise CODE128.
String barcodeFormat(Object? code) {
  final d = normalizeBarcode(code);
  if (!isValidBarcode(d)) return 'CODE128';
  if (d.length == 13) return 'EAN13';
  if (d.length == 8) return 'EAN8';
  if (d.length == 14) return 'ITF14';
  return 'CODE128';
}
