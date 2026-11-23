const API_URL = 'https://api-v2.sp-today.com/api/v1/overview?lang=en&city=aleepo';
const API_KEYS = [
  '943101f775ba55ffe3a88499d6ae8050',
  '49ed094b5e2a5a51c05dc6ba9dee36e3',
  '5dcca9b756852bcdb6fc3f7cb2177dc8',
];
const CITY = 'damascus';

let cache = { rate: null, at: 0 };

export async function fetchUsdRate() {
  const now = Date.now();
  if (cache.rate && now - cache.at < 30_000) return cache.rate;

  for (const key of API_KEYS) {
    try {
      const res = await fetch(API_URL, { headers: { 'x-api-key': key } });
      if (!res.ok) continue;

      const data = await res.json();
      if (data?.ok === false) continue;

      const rates = data?.data?.rates || data?.rates;
      if (!Array.isArray(rates)) continue;

      const usd = rates.find(r => r.code === 'USD');
      if (!usd?.cities) continue;

      const rate = usd.cities[CITY]?.sell ?? usd.cities[Object.keys(usd.cities)[0]]?.sell;
      if (!rate) continue;

      cache = { rate, at: now };
      return rate;
    } catch {
      continue;
    }
  }
  return cache.rate;
}
