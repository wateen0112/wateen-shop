/// Arabic number / date formatting helpers (ar-SY), mirroring the
/// `toLocaleString('ar-SY')` calls of the React app.
library;

import 'package:intl/intl.dart';

final NumberFormat _arNumber = _safeNumberFormat();

NumberFormat _safeNumberFormat() {
  try {
    return NumberFormat('#,##0.##', 'ar_SY');
  } catch (_) {
    return NumberFormat('#,##0.##');
  }
}

/// Formats a number with Arabic-Indic digits and the Arabic thousands separator.
/// `null` → an em dash, exactly like the React `fmt()` helpers.
String fmtNum(num? value) {
  if (value == null) return '—';
  return _arNumber.format(value);
}

/// Formats a number keeping up to 2 decimals but never showing `,00`.
String fmtAmount(num? value) {
  if (value == null) return '—';
  return _arNumber.format(value);
}

String fmtDate(DateTime? date) {
  if (date == null) return '';
  try {
    return DateFormat('d MMM yyyy', 'ar_SY').format(date);
  } catch (_) {
    return DateFormat('d MMM yyyy').format(date);
  }
}

String fmtDateTime(DateTime? date) {
  if (date == null) return '';
  try {
    return DateFormat('d MMM yyyy • h:mm a', 'ar_SY').format(date);
  } catch (_) {
    return DateFormat('d MMM yyyy • h:mm a').format(date);
  }
}

String fmtTime(DateTime? date) {
  if (date == null) return '';
  try {
    return DateFormat('h:mm a', 'ar_SY').format(date);
  } catch (_) {
    return DateFormat('h:mm a').format(date);
  }
}
