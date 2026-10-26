const express = require('express');
const Sale = require('../models/Sale');
const Product = require('../models/Product');
const Customer = require('../models/Customer');
const Debt = require('../models/Debt');
const { getUsdRate } = require('../rates');
const { requirePerm } = require('../middleware/auth');
const { audit, money } = require('../audit');
const router = express.Router();

// تسجيل عملية بيع (بالباركود أو بالـ id)
// onCredit = true → البيع يُسجَّل كدين على شخص محدد بدل دخوله الصندوق
router.post('/', requirePerm('sales.create'), async (req, res) => {
  const { barcode, productId, quantity, onCredit, customerId, name } = req.body;
  const q = Number(quantity) || 1;
  let p = null;
  if (barcode && String(barcode).trim()) { p = await Product.findOne({ barcode: String(barcode).trim() }); }
  if (!p && productId) { p = await Product.findById(productId); }
  if (!p && name && String(name).trim()) {
    const cleaned = String(name).trim();
    const esc = cleaned.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    p = await Product.findOne({ name: new RegExp('^' + esc + '$', 'i') });
    if (!p) { p = await Product.findOne({ name: new RegExp(esc, 'i') }).sort({ updatedAt: -1 }); }
  }
  if (!p) return res.status(404).json({ error: 'المنتج غير موجود' });

  const factor = p.conversionFactor || 1;
  const qtyInSaleUnits = q * factor;
  if (p.quantity < qtyInSaleUnits) return res.status(400).json({ error: `الكمية غير كافية (المتاح: ${p.quantity} ${p.saleUnit || p.unit || 'قطعة'})` });

  let customer = null;
  if (onCredit) {
    customer = await Customer.findById(customerId);
    if (!customer) return res.status(400).json({ error: 'اختر الشخص صاحب الدين' });
  }

  const usdRate = await getUsdRate();
  const salePrice = p.currentSalePrice;
  if (!salePrice) return res.status(400).json({ error: 'لا يوجد سعر بيع للمنتج' });

  // تكلفة وحدة البيع الواحدة = سعر وحدة الشراء ÷ معامل التحويل
  const unitCost = p.unitCost;
  const sellUnit = p.saleUnit || p.unit || 'قطعة';
  p.quantity -= qtyInSaleUnits;
  const sale = new Sale({
    product: p._id, quantity: q, salePrice,
    purchasePrice: unitCost, purchaseCurrency: p.purchaseCurrency,
    usdRate: usdRate || 0,
    onCredit: !!onCredit,
    customer: customer ? customer._id : undefined,
  });
  await Promise.all([p.save(), sale.save()]);

  // إضافة قيمة البيع إلى دين الشخص
  if (customer) {
    await Debt.create({
      customer: customer._id,
      type: 'debit',
      amount: salePrice * q,
      note: `بيع على الحساب — ${p.name}`,
      source: 'sale',
      sale: sale._id,
    });
  }

  await audit(req, {
    action: 'sale.create',
    entity: 'sale',
    entityId: sale._id,
    label: p.name,
    summary: `باع ${q} ${sellUnit} من «${p.name}» بمبلغ ${money(salePrice * q)}` +
      (customer ? ` بالدين للزبون «${customer.name}»` : ' نقداً'),
    details: {
      productId: String(p._id),
      barcode: p.barcode,
      quantity: q,
      unit: sellUnit,
      salePrice,
      total: salePrice * q,
      unitCost,
      conversion: factor,
      qtyInSaleUnits,
      onCredit: !!onCredit,
      customer: customer ? { id: String(customer._id), name: customer.name } : null,
      remainingQuantity: p.quantity,
    },
  });

  res.status(201).json(sale);
});

// الربح الصافي: من المبيعات ناقص المصروفات (كل شيء بالليرة)
router.get('/profit', requirePerm('reports.view', 'cashbox.view'), async (req, res) => {
  const sales = await Sale.find();
  const totalProfit = sales.reduce((s, x) => s + x.totalProfitSYP, 0);
  res.json({ totalProfitSYP: totalProfit, salesCount: sales.length });
});

module.exports = router;
