// سعر الدولار من sp-today: data.rates[code=USD].cities[CITY].sell
// نستخدم سعر "sell" لأنه ما تدفعه فعلياً لشراء الدولار (تكلفة الشراء بالجملة)
// المفتاح يُرسل عبر ترويسة x-api-key (أو ?api_key= — كلاهما مقبول لدى الـ API)
// cache لمدة 10 دقائق
let cache = { rate: null, at: 0 };

async function getUsdRate() {
  const now = Date.now();
  if (cache.rate && now - cache.at < 10 * 60 * 1000) return cache.rate;

  const url = process.env.CURRENCY_API_URL;
  if (!url) return cache.rate; // ponytail: بدون API نرجع آخر قيمة (أو null)

  try {
    const headers = {};
    if (process.env.CURRENCY_API_KEY) headers['x-api-key'] = process.env.CURRENCY_API_KEY;
    const res = await fetch(url, { headers });
    const data = await res.json();
    if (data?.ok === false) throw new Error(`${data.error?.code}: ${data.error?.message}`);
    const city = process.env.CURRENCY_CITY || 'damascus';
    const usd = data?.data?.rates?.find(r => r.code === 'USD');
    const rate = usd?.cities?.[city]?.sell ?? usd?.cities?.[Object.keys(usd?.cities || {})[0]]?.sell;
    if (!rate) throw new Error('USD rate not found in API response');
    cache = { rate, at: now };
    return rate;
  } catch (e) {
    console.error('Rate fetch failed:', e.message);
    return cache.rate;
  }
}

module.exports = { getUsdRate };

// فحص سريع: node rates.js — يفشل إذا انكسر جلب السعر
if (require.main === module) {
  require('dotenv').config();
  getUsdRate().then(r => {
    console.log('USD rate:', r);
    if (!r) { console.error('FAIL: no rate'); process.exit(1); }
  });
}
