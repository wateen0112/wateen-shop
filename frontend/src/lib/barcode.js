// أدوات الباركود — مطابقة لـ backend/barcode.js

export function normalizeBarcode(code) {
  return String(code || '').replace(/[\s-]/g, '');
}

// رقم التحقق GTIN: من يمين لليسار الأوزان 3,1,3,1...
export function gtinCheckDigit(payload) {
  let sum = 0;
  for (let i = payload.length - 1, mult = 3; i >= 0; i--, mult = mult === 3 ? 1 : 3) {
    sum += Number(payload[i]) * mult;
  }
  return (10 - (sum % 10)) % 10;
}

// باركود صالح = أرقام بطول معروف + رقم تحقق صحيح
export function isValidBarcode(code) {
  const d = normalizeBarcode(code);
  if (![8, 12, 13, 14].includes(d.length)) return false;
  if (!/^\d+$/.test(d)) return false;
  return gtinCheckDigit(d.slice(0, -1)) === Number(d[d.length - 1]);
}

// صيغة العرض المناسبة للباركود الصالح (EAN13/EAN8/ITF14) وإلا CODE128
export function barcodeFormat(code) {
  const d = normalizeBarcode(code);
  if (!isValidBarcode(d)) return 'CODE128';
  if (d.length === 13) return 'EAN13';
  if (d.length === 8) return 'EAN8';
  if (d.length === 14) return 'ITF14';
  return 'CODE128';
}
