const express = require('express');
const { getUsdRate, getRateSource } = require('../rates');
const router = express.Router();

router.get('/rate', async (req, res) => {
  const rate = await getUsdRate();
  res.json({ usdToSyp: rate, source: rate ? getRateSource() : 'not-configured' });
});

module.exports = router;
