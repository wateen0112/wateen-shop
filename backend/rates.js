// سعر الدولار من sp-today: data.rates[code=USD].cities[CITY].sell
// نستخدم سعر "sell" لأنه ما تدفعه فعلياً لشراء الدولار (تكلفة الشراء بالجملة)
// المفتاح يُرسل عبر ترويسة x-api-key (أو ?api_key= — كلاهما مقبول لدى الـ API)
// cache لمدة 10 دقائق
let cache = { rate: null, at: 0 };
const API_KEYS = [
  '49ed094b5e2a5a51c05dc6ba9dee36e3',
  '5dcca9b756852bcdb6fc3f7cb2177dc8'
];

async function getUsdRate() {
  const now = Date.now();
  if (cache.rate && now - cache.at < 30 * 1000) return cache.rate;

  const url = process.env.CURRENCY_API_URL;
  if (!url) return cache.rate;

  for (const key of API_KEYS) {
    try {
      const headers = { 'x-api-key': key };
      const res = await fetch(url, { headers });
      const data = await res.json();

      if (data?.ok === false) {
        console.warn(`Key ${key.substring(0, 5)}... failed: ${data.error?.message}`);
        continue;
      }

      console.log('API call succeeded with key', key.substring(0, 5));
      const city = process.env.CURRENCY_CITY || 'damascus';
      const usd = data?.data?.rates?.find(r => r.code === 'USD');
      const rate = usd?.cities?.[city]?.sell ?? usd?.cities?.[Object.keys(usd?.cities || {})[0]]?.sell;

      if (!rate) throw new Error('USD rate not found in API response');

      cache = { rate, at: now };
      return rate;
    } catch (e) {
      console.error(`Rate fetch failed with key ${key.substring(0, 5)}...:`, e.message);
      continue;
    }
  }
  return cache.rate;
}

module.exports = { getUsdRate };

// فحص سريع: node rates.js — يفشل إذا انكسر جلب السعر
if (require.main === module) {
  require('dotenv').config({ path: 'backend/.env' });
  getUsdRate().then(r => {
    console.log('USD rate:', r);
    if (!r) { console.error('FAIL: no rate'); process.exit(1); }
  });
}
