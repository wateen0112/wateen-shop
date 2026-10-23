const express = require('express');
const Expense = require('../models/Expense');
const { requirePerm } = require('../middleware/auth');
const { audit, money } = require('../audit');
const router = express.Router();

router.get('/', requirePerm('expenses.view'), async (req, res) => res.json(await Expense.find().sort('-date')));

router.post('/', requirePerm('expenses.edit'), async (req, res) => {
  const e = new Expense(req.body);
  await e.save();
  await audit(req, {
    action: 'expense.create',
    entity: 'expense',
    entityId: e._id,
    label: e.title,
    summary: `أضاف مصروف «${e.title}» بمبلغ ${money(e.amount, e.currency)}` +
      (e.note ? ` — ${e.note}` : ''),
    details: {
      title: e.title,
      amount: e.amount,
      currency: e.currency,
      note: e.note,
      date: e.date,
    },
  });
  res.status(201).json(e);
});

router.delete('/:id', requirePerm('expenses.edit'), async (req, res) => {
  const e = await Expense.findByIdAndDelete(req.params.id);
  if (e) {
    await audit(req, {
      action: 'expense.delete',
      entity: 'expense',
      entityId: e._id,
      label: e.title,
      summary: `حذف مصروف «${e.title}» بمبلغ ${money(e.amount, e.currency)}`,
      details: {
        title: e.title,
        amount: e.amount,
        currency: e.currency,
        note: e.note,
        date: e.date,
      },
    });
  }
  res.json({ ok: true });
});

// مجموع المصروفات (بالليرة بعد التحويل بسعر الدولار الحالي)
router.get('/total', requirePerm('expenses.view', 'reports.view'), async (req, res) => {
  const { getUsdRate } = require('../rates');
  const rate = (await getUsdRate()) || 0;
  const expenses = await Expense.find();
  const total = expenses.reduce((s, e) => s + (e.currency === 'USD' ? e.amount * rate : e.amount), 0);
  res.json({ totalSYP: total });
});

module.exports = router;
