const express = require('express');
const Inventory = require('../models/Inventory');
const Product = require('../models/Product');
const { requirePerm } = require('../middleware/auth');
const { audit } = require('../audit');
const router = express.Router();

// جلب كل المنتجات مع كمياتها المسجلة للجرد
router.get('/sheet', requirePerm('inventory.view'), async (req, res) => {
  const products = await Product.find().select('name unit quantity barcode');
  res.json(products);
});

// حفظ جرد — items: [{productId, actualQty}]، ويحدّث الكميات المسجلة للفعلية
router.post('/', requirePerm('inventory.edit'), async (req, res) => {
  const items = [];
  for (const it of req.body.items || []) {
    const p = await Product.findById(it.productId);
    if (!p) continue;
    items.push({ product: p._id, name: p.name, recordedQty: p.quantity, actualQty: it.actualQty });
    p.quantity = it.actualQty; // ponytail: نعتبر نتيجة الجرد هي الصح — عدّل هنا لو بدك يبقى الفرق مجرد تقرير
    await p.save();
  }
  const inv = new Inventory({ items, note: req.body.note || '' });
  await inv.save();
  const diffItems = items.filter(it => Number(it.recordedQty) !== Number(it.actualQty));
  await audit(req, {
    action: 'inventory.create',
    entity: 'inventory',
    entityId: inv._id,
    label: req.body.note || '',
    summary: `أجرى جرداً على ${items.length} صنفاً — ${diffItems.length} صنف تغيّرت كميته` +
      (req.body.note ? ` — ${req.body.note}` : ''),
    details: {
      note: req.body.note || '',
      itemsCount: items.length,
      changedCount: diffItems.length,
      changes: diffItems.map(it => ({
        productId: String(it.product),
        name: it.name,
        from: it.recordedQty,
        to: it.actualQty,
      })),
    },
  });
  res.status(201).json(inv);
});

router.get('/', requirePerm('inventory.view'), async (req, res) => res.json(await Inventory.find().sort('-date')));

module.exports = router;
