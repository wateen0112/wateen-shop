const express = require('express');
const Product = require('../models/Product');
const { normalizeBarcode, gtinCheckDigit, isValidBarcode } = require('../barcode');
const { requirePerm } = require('../middleware/auth');
const { audit, diff, describeChanges, money } = require('../audit');
const router = express.Router();

// توليد باركود داخلي فريد للمنتجات بدون باركود — EAN-13 صالح (بادئة 20 + رقم تحقق)
async function generateInternalBarcode() {
  // نطاق 2000000000000+ لتجنب التعارض مع الباركودات EAN الحقيقية
  const last = await Product.findOne({ barcode: /^2\d{12}$/ }).sort({ barcode: -1 }).lean();
  let payload = '200000000000';
  if (last) {
    payload = (BigInt(String(last.barcode).slice(0, 12)) + 1n).toString().padStart(12, '0');
  }
  return payload + String(gtinCheckDigit(payload));
}

router.get('/', requirePerm('products.view'), async (req, res) => {
  const { search } = req.query;
  const q = search ? { $or: [{ name: new RegExp(search, 'i') }, { barcode: search }] } : {};
  res.json(await Product.find(q).sort('-createdAt'));
});

// المنتجات بدون باركود صالح — جاهزة لتوليد شبكة PDF
router.get('/no-barcode', requirePerm('barcodes.view', 'products.view'), async (req, res) => {
  const products = await Product.find().select('name unit barcode');
  res.json(products.filter(p => !isValidBarcode(p.barcode)));
});

router.post('/', requirePerm('products.edit'), async (req, res) => {
  try {
    const {
      name, barcode, unit, purchaseUnit, saleUnit, conversion,
      quantity, quantityInPurchaseUnits, quantityPurchase, quantityInBuy,
      purchasePrice, purchaseCurrency, salePrice,
    } = req.body;
    const entered = normalizeBarcode(barcode);
    // باركود فارغ أو غير صالح => نولّد واحداً تلقائياً
    const barcodeGenerated = !isValidBarcode(entered);
    const sellUnit = String(saleUnit || unit || 'قطعة').trim() || 'قطعة';
    const buyUnit = String(purchaseUnit || sellUnit).trim() || sellUnit;
    const factor = Number(conversion) > 0 ? Number(conversion) : 1;
    let qty = Number(quantity) || 0;
    const qtyInPurchase = Number(quantityInPurchaseUnits ?? quantityPurchase ?? quantityInBuy);
    if (Number.isFinite(qtyInPurchase) && qtyInPurchase > 0) {
      qty = qtyInPurchase * factor;
    }
    const product = new Product({
      name,
      barcode: barcodeGenerated ? await generateInternalBarcode() : entered,
      unit: sellUnit,
      purchaseUnit: buyUnit,
      saleUnit: sellUnit,
      conversion: factor,
      quantity: qty,
      purchasePrice, purchaseCurrency: purchaseCurrency || 'SYP',
      salePrices: salePrice ? [{ price: salePrice }] : [],
    });
    const qtyInPurchaseUnitsDisplay = Number.isFinite(qtyInPurchase) && qtyInPurchase > 0 ? qtyInPurchase : (factor ? qty / factor : qty);
    await product.save();
    const unitCost = product.unitCost;
    await audit(req, {
      action: 'product.create',
      entity: 'product',
      entityId: product._id,
      label: product.name,
      summary: `أضاف صنف «${product.name}» — ${product.quantity} ${sellUnit}` +
        (salePrice ? ` بسعر بيع ${money(salePrice)}` : '') +
        ` — الشراء بـ${buyUnit} (كل ${buyUnit} = ${factor} ${sellUnit})` +
        (barcodeGenerated ? ' (باركود مولّد تلقائياً)' : ''),
      details: {
        barcode: product.barcode,
        unit: product.unit,
        purchaseUnit: buyUnit,
        saleUnit: sellUnit,
        conversion: factor,
        unitCost,
        quantity: product.quantity,
        quantityInPurchaseUnits: qtyInPurchaseUnitsDisplay,
        purchasePrice: product.purchasePrice,
        purchaseCurrency: product.purchaseCurrency,
        salePrice: salePrice || null,
        barcodeGenerated,
      },
    });
    res.status(201).json({ ...product.toJSON(), barcodeGenerated });
  } catch (e) {
    res.status(400).json({ error: e.code === 11000 ? 'الباركود مستخدم مسبقاً' : e.message });
  }
});

// توليد باركودات — ids: عناصر مختارة، all: كل الأصناف بلا باركود صالح
router.post('/generate-barcodes', requirePerm('barcodes.manage', 'products.edit'), async (req, res) => {
  const { ids, all } = req.body || {};
  const products = all
    ? await Product.find()
    : await Product.find({ _id: { $in: ids || [] } });

  const out = [];
  let generatedCount = 0;
  for (const p of products) {
    if (!isValidBarcode(p.barcode)) {
      p.barcode = await generateInternalBarcode();
      await p.save();
      generatedCount += 1;
      out.push({ id: p._id, name: p.name, barcode: p.barcode, generated: true });
    } else {
      out.push({ id: p._id, name: p.name, barcode: p.barcode, generated: false });
    }
  }
  await audit(req, {
    action: 'product.barcode_generate',
    entity: 'product',
    label: all ? 'كل الأصناف' : 'أصناف مختارة',
    summary: generatedCount
      ? `ولّد باركودات لـ ${generatedCount} صنفاً من أصل ${out.length}`
      : `تحقّق من باركودات ${out.length} صنفاً — لا حاجة لتوليد جديد`,
    details: {
      requested: out.length,
      generated: generatedCount,
      all: !!all,
      products: out.filter(x => x.generated).map(x => ({ id: x.id, name: x.name, barcode: x.barcode })),
    },
  });
  res.json(out);
});

// إضافة سعر بيع جديد (تغيّر السوق)
router.post('/:id/sale-price', requirePerm('products.edit'), async (req, res) => {
  const p = await Product.findById(req.params.id);
  if (!p) return res.status(404).json({ error: 'غير موجود' });
  p.salePrices.push({ price: req.body.price, note: req.body.note || '' });
  await p.save();
  await audit(req, {
    action: 'product.price_add',
    entity: 'product',
    entityId: p._id,
    label: p.name,
    summary: `أضاف سعر بيع جديد للصنف «${p.name}»: ${money(req.body.price)}` +
      (req.body.note ? ` — ${req.body.note}` : ''),
    details: {
      price: req.body.price,
      note: req.body.note || '',
      previousPrice: p.salePrices.length > 1 ? p.salePrices[p.salePrices.length - 2].price : null,
    },
  });
  res.json(p);
});

router.put('/:id', requirePerm('products.edit'), async (req, res) => {
  try {
    const before = await Product.findById(req.params.id).lean();
    if (!before) return res.status(404).json({ error: 'غير موجود' });
    const body = { ...req.body };
    if ('barcode' in body) {
      const code = normalizeBarcode(body.barcode);
      body.barcode = isValidBarcode(code) ? code : await generateInternalBarcode();
    }
    if ('conversion' in body) {
      const factor = Number(body.conversion);
      body.conversion = Number.isFinite(factor) && factor > 0 ? factor : 1;
    }
    // الحفاظ على توافق حقل unit القديم مع وحدة البيع
    if ('saleUnit' in body) body.unit = body.saleUnit;
    else if ('unit' in body) body.saleUnit = body.unit;
    if ('purchaseUnit' in body && !String(body.purchaseUnit || '').trim()) {
      delete body.purchaseUnit;
    }
    if ('saleUnit' in body && !String(body.saleUnit || '').trim()) {
      delete body.saleUnit;
      delete body.unit;
    }
    const p = await Product.findByIdAndUpdate(req.params.id, body, { new: true, runValidators: true });
    const changes = diff(before, p.toObject(), [
      'name', 'barcode', 'unit', 'quantity', 'purchasePrice', 'purchaseCurrency',
      'purchaseUnit', 'saleUnit', 'conversion',
    ]);
    await audit(req, {
      action: 'product.update',
      entity: 'product',
      entityId: p._id,
      label: p.name,
      summary: changes.length
        ? `عدّل الصنف «${p.name}»: ${describeChanges(changes)}`
        : `حفظ الصنف «${p.name}» دون تغييرات فعلية`,
      details: { changes, unitCost: p.unitCost, conversion: p.conversionFactor },
    });
    res.json(p);
  } catch (e) {
    res.status(400).json({ error: e.code === 11000 ? 'الباركود مستخدم مسبقاً' : e.message });
  }
});

router.delete('/:id', requirePerm('products.edit'), async (req, res) => {
  const p = await Product.findByIdAndDelete(req.params.id);
  if (p) {
    await audit(req, {
      action: 'product.delete',
      entity: 'product',
      entityId: p._id,
      label: p.name,
      summary: `حذف الصنف «${p.name}» (الكمية المتبقية: ${p.quantity} ${p.unit})`,
      details: {
        barcode: p.barcode,
        unit: p.unit,
        purchaseUnit: p.purchaseUnit,
        saleUnit: p.saleUnit,
        conversion: p.conversionFactor,
        unitCost: p.unitCost,
        quantity: p.quantity,
        purchasePrice: p.purchasePrice,
        purchaseCurrency: p.purchaseCurrency,
      },
    });
  }
  res.json({ ok: true });
});

module.exports = router;
