const express = require('express');
const { getUsdRate } = require('../rates');
const router = express.Router();

router.get('/rate', async (req, res) => {
  const rate = await getUsdRate();
  res.json({ usdToSyp: rate, source: rate ? 'api' : 'not-configured' });
});

module.exports = router;
