// سعر صرف الدولار مقابل الليرة السورية
// المصدر الأساسي: kazawallet (بدون مفتاح ولا مصادقة) — نستخدم حقل SYP_TO
// المصدر الاحتياطي: sp-today (قائمة مفاتيح، إذا فشل المصدر الأساسي)
// cache قصير (30 ثانية) حتى يعطي التحديث من الواجهة نتيجة جديدة
let cache = { rate: null, at: 0, source: null };

const KAZA_URL = 'https://www.kazawallet.com/api/rate';

// مفاتيح احتياطية (sp-today) — تُجرّب بالترتيب عند فشل المصدر الأساسي
const SP_TODAY_KEYS = [
  '49ed094b5e2a5a51c05dc6ba9dee36e3',
  '5dcca9b756852bcdb6fc3f7cb2177dc8',
];

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

// بحث عام في استجابة JSON عن قيمة SYP_TO (يفضّل المسار الذي يحتوي USD)
function pickSypTo(node, path = []) {
  if (!node || typeof node !== 'object') return null;

  if (Array.isArray(node)) {
    for (let i = 0; i < node.length; i += 1) {
      const found = pickSypTo(node[i], path);
      if (found) return found;
    }
    return null;
  }

  let fallback = null;
  for (const [key, value] of Object.entries(node)) {
    const lower = key.toLowerCase();
    // الحقل المستهدف: SYP_TO (بأي صيغة) — قيمة رقمية أو نص رقمي
    if (lower === 'syp_to' || lower === 'sypto' || lower === 'syp_to_rate') {
      const num = Number(value);
      if (Number.isFinite(num) && num > 0) {
        const isUsd = path.some(p => /usd/i.test(String(p))) || /usd/i.test(lower);
        if (isUsd) return num;
        if (!fallback) fallback = num;
      }
      continue;
    }
    const found = pickSypTo(value, [...path, key]);
    if (found && path.concat(key).some(p => /usd/i.test(String(p)))) return found;
    if (found && !fallback) fallback = found;
  }
  return fallback;
}

async function fetchKazaRate() {
  const res = await fetch(KAZA_URL, {
    headers: { 'User-Agent': UA, Accept: 'application/json' },
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`kazawallet HTTP ${res.status}`);
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    throw new Error('kazawallet returned non-JSON (security checkpoint)');
  }
  if (data?.error) throw new Error(`kazawallet: ${data.error.code || data.error.message || 'error'}`);
  const rate = pickSypTo(data);
  if (!rate) throw new Error('kazawallet: SYP_TO not found');
  return rate;
}

async function fetchSpTodayRate() {
  const url = process.env.CURRENCY_API_URL;
  if (!url) throw new Error('sp-today URL not configured');

  for (const key of SP_TODAY_KEYS) {
    try {
      const res = await fetch(url, { headers: { 'x-api-key': key } });
      const data = await res.json();
      if (data?.ok === false) throw new Error(data.error?.message || 'api error');

      const city = process.env.CURRENCY_CITY || 'damascus';
      const usd = data?.data?.rates?.find(r => r.code === 'USD');
      const rate = usd?.cities?.[city]?.sell
        ?? usd?.cities?.[Object.keys(usd?.cities || {})[0]]?.sell;
      if (!rate) throw new Error('USD rate not found');
      return rate;
    } catch (e) {
      console.warn(`sp-today key ${key.slice(0, 5)}… failed: ${e.message}`);
    }
  }
  throw new Error('all sp-today keys failed');
}

async function getUsdRate() {
  const now = Date.now();
  if (cache.rate && now - cache.at < 30 * 1000) return cache.rate;

  // 1) المصدر الأساسي
  try {
    const rate = await fetchKazaRate();
    cache = { rate, at: now, source: 'kazawallet' };
    return rate;
  } catch (e) {
    console.error('kazawallet rate failed:', e.message);
  }

  // 2) المصدر الاحتياطي
  try {
    const rate = await fetchSpTodayRate();
    cache = { rate, at: now, source: 'sp-today' };
    return rate;
  } catch (e) {
    console.error('sp-today rate failed:', e.message);
  }

  return cache.rate;
}

function getRateSource() {
  return cache.source;
}

module.exports = { getUsdRate, getRateSource };

// فحص سريع: node rates.js
if (require.main === module) {
  require('dotenv').config();
  getUsdRate().then(r => {
    console.log('USD rate:', r, 'source:', getRateSource());
    if (!r) process.exit(1);
  });
}
