const express = require('express');
const Unit = require('../models/Unit');
const Product = require('../models/Product');
const { requireAdmin } = require('../middleware/auth');
const { audit } = require('../audit');
const router = express.Router();

// وحدات افتراضية عند أول استخدام — يمكن للأدمن حذف/إضافة غيرها
const DEFAULT_UNITS = ['قطعة', 'علبة', 'كرتون', 'دستة', 'كيس', 'كيلو', 'لتر', 'متر'];

async function ensureDefaults() {
  const count = await Unit.countDocuments();
  if (count > 0) return;
  await Unit.insertMany(DEFAULT_UNITS.map(name => ({ name })));
}

// عدد الأصناف التي تستخدم كل وحدة (شراء أو بيع أو الوحدة القديمة)
async function usageMap() {
  const products = await Product.find().select('unit purchaseUnit saleUnit').lean();
  const used = new Map();
  const bump = (name) => {
    if (!name) return;
    used.set(name, (used.get(name) || 0) + 1);
  };
  for (const p of products) {
    bump(p.unit);
    bump(p.purchaseUnit);
    bump(p.saleUnit);
  }
  return used;
}

// كل المستخدمين يحتاجون القائمة لاختيار الوحدات عند إضافة صنف
router.get('/', async (req, res) => {
  await ensureDefaults();
  const [units, used] = await Promise.all([Unit.find().sort('createdAt'), usageMap()]);
  res.json(units.map(u => ({
    ...u.toJSON(),
    products: used.get(u.name) || 0,
  })));
});

router.post('/', requireAdmin, async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    if (!name) return res.status(400).json({ error: 'اسم الوحدة مطلوب' });
    const unit = await Unit.create({ name, note: String(req.body.note || '').trim() });
    await audit(req, {
      action: 'unit.create',
      entity: 'unit',
      entityId: unit._id,
      label: unit.name,
      summary: `أضاف وحدة قياس «${unit.name}»` + (unit.note ? ` — ${unit.note}` : ''),
      details: { note: unit.note },
    });
    res.status(201).json(unit);
  } catch (e) {
    res.status(400).json({ error: e.code === 11000 ? 'هذه الوحدة موجودة مسبقاً' : e.message });
  }
});

router.put('/:id', requireAdmin, async (req, res) => {
  try {
    const unit = await Unit.findById(req.params.id);
    if (!unit) return res.status(404).json({ error: 'الوحدة غير موجودة' });
    const before = unit.name;
    if ('name' in req.body) {
      const name = String(req.body.name || '').trim();
      if (!name) return res.status(400).json({ error: 'اسم الوحدة مطلوب' });
      unit.name = name;
    }
    if ('note' in req.body) unit.note = String(req.body.note || '').trim();
    await unit.save();
    // تحديث الأصناف التي كانت تستخدم الاسم القديم
    let affected = 0;
    if (before !== unit.name) {
      const r = await Product.updateMany(
        { $or: [{ unit: before }, { purchaseUnit: before }, { saleUnit: before }] },
        [{ $set: {
          unit: { $cond: [{ $eq: ['$unit', before] }, unit.name, '$unit'] },
          purchaseUnit: { $cond: [{ $eq: ['$purchaseUnit', before] }, unit.name, '$purchaseUnit'] },
          saleUnit: { $cond: [{ $eq: ['$saleUnit', before] }, unit.name, '$saleUnit'] },
        } }],
      );
      affected = r.modifiedCount || 0;
    }
    await audit(req, {
      action: 'unit.update',
      entity: 'unit',
      entityId: unit._id,
      label: unit.name,
      summary: before !== unit.name
        ? `عدّل وحدة القياس «${before}» إلى «${unit.name}» (تحدّث ${affected} صنفاً)`
        : `حفظ وحدة القياس «${unit.name}»`,
      details: { before, after: unit.name, note: unit.note, affected },
    });
    res.json(unit);
  } catch (e) {
    res.status(400).json({ error: e.code === 11000 ? 'هذه الوحدة موجودة مسبقاً' : e.message });
  }
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const unit = await Unit.findById(req.params.id);
  if (!unit) return res.status(404).json({ error: 'الوحدة غير موجودة' });
  const used = await Product.countDocuments({
    $or: [{ unit: unit.name }, { purchaseUnit: unit.name }, { saleUnit: unit.name }],
  });
  if (used > 0) {
    return res.status(400).json({ error: `لا يمكن حذف وحدة تستخدمها ${used} أصناف — غيّر وحداتها أولاً` });
  }
  await Unit.deleteOne({ _id: unit._id });
  await audit(req, {
    action: 'unit.delete',
    entity: 'unit',
    entityId: unit._id,
    label: unit.name,
    summary: `حذف وحدة القياس «${unit.name}»`,
    details: { note: unit.note },
  });
  res.json({ ok: true });
});

module.exports = router;
