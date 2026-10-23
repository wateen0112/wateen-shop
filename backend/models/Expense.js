const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema({
  title: { type: String, required: true },
  amount: { type: Number, required: true },
  currency: { type: String, enum: ['SYP', 'USD'], default: 'SYP' },
  date: { type: Date, default: Date.now },
  note: { type: String, default: '' },
});

module.exports = mongoose.model('Expense', expenseSchema);
