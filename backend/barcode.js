// أدوات الباركود — تطبيع + تحقق من صحة GTIN (EAN-8 / UPC-A / EAN-13 / GTIN-14)

// إزالة المسافات والشرطات
function normalizeBarcode(code) {
  return String(code || '').replace(/[\s-]/g, '');
}

// رقم التحقق: من يمين لليسار الأوزان 3,1,3,1...
function gtinCheckDigit(payload) {
  let sum = 0;
  for (let i = payload.length - 1, mult = 3; i >= 0; i--, mult = mult === 3 ? 1 : 3) {
    sum += Number(payload[i]) * mult;
  }
  return (10 - (sum % 10)) % 10;
}

// باركود صالح = أرقام بطول معروف + رقم تحقق صحيح (يقرأه الماسح الضوئي)
function isValidBarcode(code) {
  const d = normalizeBarcode(code);
  if (![8, 12, 13, 14].includes(d.length)) return false;
  if (!/^\d+$/.test(d)) return false;
  return gtinCheckDigit(d.slice(0, -1)) === Number(d[d.length - 1]);
}

module.exports = { normalizeBarcode, gtinCheckDigit, isValidBarcode };
