const express = require('express');
const Cashbox = require('../models/Cashbox');
const Sale = require('../models/Sale');
const Expense = require('../models/Expense');
const Customer = require('../models/Customer');
const Debt = require('../models/Debt');
const { getUsdRate } = require('../rates');
const { requirePerm } = require('../middleware/auth');
const { audit, money } = require('../audit');
const router = express.Router();

async function getBox() {
  const box = await Cashbox.findOne({ key: 'main' });
  const rate = (await getUsdRate()) || 0;

  const sales = await Sale.find();
  const salesCash = sales.filter(s => !s.onCredit).reduce((sum, s) => sum + s.salePrice * s.quantity, 0);
  const salesCredit = sales.filter(s => s.onCredit).reduce((sum, s) => sum + s.salePrice * s.quantity, 0);
  const salesProfit = sales.reduce((sum, s) => sum + s.totalProfitSYP, 0);

  const expenses = await Expense.find();
  const expensesTotal = expenses.reduce((sum, e) => sum + (e.currency === 'USD' ? e.amount * rate : e.amount), 0);

  const [initialBalance, customers] = await Promise.all([
    box ? box.initialBalance : 0,
    Customer.find().select('initialBalance'),
  ]);
  const movements = await Debt.aggregate([
    {
      $group: {
        _id: null,
        debit: { $sum: { $cond: [{ $eq: ['$type', 'debit'] }, '$amount', 0] } },
        credit: { $sum: { $cond: [{ $eq: ['$type', 'credit'] }, '$amount', 0] } },
      },
    },
  ]);
  const initialDebt = customers.reduce((sum, c) => sum + (c.initialBalance || 0), 0);
  const m = movements[0] || { debit: 0, credit: 0 };
  const debtsTotal = initialDebt + m.debit - m.credit;

  return {
    initialBalance,
    salesCash,
    salesCredit,
    salesProfit,
    expensesTotal,
    current: initialBalance + salesCash - expensesTotal,
    netProfit: salesProfit - expensesTotal,
    debtsTotal,
    salesCount: sales.length,
  };
}

// ملخّص الصندوق
router.get('/', requirePerm('cashbox.view'), async (req, res) => res.json(await getBox()));

// تعيين الرصيد الابتدائي
router.put('/', requirePerm('cashbox.edit'), async (req, res) => {
  const before = await Cashbox.findOne({ key: 'main' }).lean();
  const previous = before ? before.initialBalance : 0;
  const initialBalance = Number(req.body.initialBalance) || 0;
  const box = await Cashbox.findOneAndUpdate(
    { key: 'main' },
    { initialBalance, updatedAt: new Date() },
    { new: true, upsert: true }
  );
  await audit(req, {
    action: 'cashbox.update',
    entity: 'cashbox',
    entityId: box._id,
    label: 'الرصيد الافتتاحي',
    summary: previous === initialBalance
      ? `حفظ الرصيد الافتتاحي للصندوق دون تغيير (${money(initialBalance)})`
      : `عدّل الرصيد الافتتاحي للصندوق من ${money(previous)} إلى ${money(initialBalance)}`,
    details: { from: previous, to: initialBalance },
  });
  res.json(await getBox());
});

module.exports = router;
