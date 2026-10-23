const express = require('express');
const Customer = require('../models/Customer');
const Debt = require('../models/Debt');
const { requirePerm } = require('../middleware/auth');
const { audit, diff, describeChanges, money } = require('../audit');
const router = express.Router();

// حساب أرصدة الديون لكل الشخص (رصيد مسبق + حركة)
async function withBalances(customers) {
  const sums = await Debt.aggregate([
    {
      $group: {
        _id: '$customer',
        debit: { $sum: { $cond: [{ $eq: ['$type', 'debit'] }, '$amount', 0] } },
        credit: { $sum: { $cond: [{ $eq: ['$type', 'credit'] }, '$amount', 0] } },
      },
    },
  ]);
  const map = new Map(sums.map(s => [String(s._id), s]));
  return customers.map(c => {
    const s = map.get(String(c._id)) || { debit: 0, credit: 0 };
    return { ...c.toJSON(), balance: (c.initialBalance || 0) + s.debit - s.credit };
  });
}

// كل الأشخاص مع أرصدتهم
router.get('/', requirePerm('debts.view'), async (req, res) => {
  const customers = await Customer.find().sort('name');
  res.json(await withBalances(customers));
});

// شخص واحد مع كشف حسابه
router.get('/:id', requirePerm('debts.view'), async (req, res) => {
  const c = await Customer.findById(req.params.id);
  if (!c) return res.status(404).json({ error: 'الشخص غير موجود' });
  const [withBalance] = await withBalances([c]);
  const movements = await Debt.find({ customer: c._id }).sort('-date');
  res.json({ ...withBalance, movements });
});

// إنشاء شخص مع رصيد مسبق للدين
router.post('/', requirePerm('debts.edit'), async (req, res) => {
  try {
    const { name, phone, note, initialBalance } = req.body;
    const c = new Customer({
      name,
      phone: phone || '',
      note: note || '',
      initialBalance: Number(initialBalance) || 0,
    });
    await c.save();
    await audit(req, {
      action: 'customer.create',
      entity: 'customer',
      entityId: c._id,
      label: c.name,
      summary: `أضاف الزبون «${c.name}»` +
        (c.initialBalance ? ` برصيد افتتاحي ${money(c.initialBalance)}` : ''),
      details: {
        name: c.name,
        phone: c.phone,
        note: c.note,
        initialBalance: c.initialBalance,
      },
    });
    res.status(201).json({ ...c.toJSON(), balance: c.initialBalance });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.put('/:id', requirePerm('debts.edit'), async (req, res) => {
  try {
    const before = await Customer.findById(req.params.id).lean();
    const c = await Customer.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!c) return res.status(404).json({ error: 'الشخص غير موجود' });
    const changes = diff(before, c.toObject(), ['name', 'phone', 'note', 'initialBalance']);
    await audit(req, {
      action: 'customer.update',
      entity: 'customer',
      entityId: c._id,
      label: c.name,
      summary: changes.length
        ? `عدّل بيانات الزبون «${c.name}»: ${describeChanges(changes)}`
        : `حفظ بيانات الزبون «${c.name}» دون تغييرات فعلية`,
      details: { changes },
    });
    const [withBalance] = await withBalances([c]);
    res.json(withBalance);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

router.delete('/:id', requirePerm('debts.edit'), async (req, res) => {
  const c = await Customer.findById(req.params.id);
  const debtsCount = await Debt.countDocuments({ customer: req.params.id });
  await Debt.deleteMany({ customer: req.params.id });
  await Customer.findByIdAndDelete(req.params.id);
  if (c) {
    await audit(req, {
      action: 'customer.delete',
      entity: 'customer',
      entityId: c._id,
      label: c.name,
      summary: `حذف الزبون «${c.name}» مع ${debtsCount} حركة دين`,
      details: { name: c.name, phone: c.phone, initialBalance: c.initialBalance, debtsCount },
    });
  }
  res.json({ ok: true });
});

// حركة دين: type = debit (دين جديد) أو credit (تسديد)
router.post('/:id/debt', requirePerm('debts.edit'), async (req, res) => {
  try {
    const c = await Customer.findById(req.params.id);
    if (!c) return res.status(404).json({ error: 'الشخص غير موجود' });
    const amount = Number(req.body.amount);
    if (!amount || amount <= 0) return res.status(400).json({ error: 'أدخل مبلغاً أكبر من صفر' });
    const type = req.body.type === 'credit' ? 'credit' : 'debit';
    const d = await Debt.create({
      customer: c._id, type, amount,
      note: req.body.note || '',
      source: 'manual',
    });
    const [withBalance] = await withBalances([c]);
    await audit(req, {
      action: 'debt.create',
      entity: 'debt',
      entityId: d._id,
      label: c.name,
      summary: `سجّل ${type === 'debit' ? 'ديناً' : 'تسديداً'} للزبون «${c.name}» بمبلغ ${money(amount)}` +
        (d.note ? ` — ${d.note}` : ''),
      details: {
        customerId: String(c._id),
        customerName: c.name,
        type,
        typeLabel: type === 'debit' ? 'دين' : 'تسديد',
        amount,
        note: d.note,
        balanceAfter: withBalance.balance,
      },
    });
    res.status(201).json({ ...d.toJSON(), customer: withBalance });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// حذف حركة دين
router.delete('/:customerId/debt/:debtId', requirePerm('debts.edit'), async (req, res) => {
  const d = await Debt.findOneAndDelete({ _id: req.params.debtId, customer: req.params.customerId });
  if (d) {
    const c = await Customer.findById(d.customer).select('name');
    await audit(req, {
      action: 'debt.delete',
      entity: 'debt',
      entityId: d._id,
      label: c ? c.name : '',
      summary: `حذف حركة ${d.type === 'debit' ? 'دين' : 'تسديد'} بمبلغ ${money(d.amount)}` +
        (c ? ` للزبون «${c.name}»` : ''),
      details: {
        customerId: String(d.customer),
        customerName: c ? c.name : '',
        type: d.type,
        amount: d.amount,
        note: d.note,
        source: d.source,
      },
    });
  }
  res.json({ ok: true });
});

module.exports = router;
