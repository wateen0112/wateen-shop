const mongoose = require('mongoose');

// حركة دين واحدة على شخص:
// debit  = دين جديد على العميل (يزيد المديونية)
// credit = تسديد من العميل (ينقص المديونية)
const debtSchema = new mongoose.Schema({
  customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', required: true },
  type: { type: String, enum: ['debit', 'credit'], required: true },
  amount: { type: Number, required: true }, // دائماً موجب
  note: { type: String, default: '' },
  source: { type: String, enum: ['manual', 'sale'], default: 'manual' },
  sale: { type: mongoose.Schema.Types.ObjectId, ref: 'Sale' },
  date: { type: Date, default: Date.now },
});

debtSchema.set('toJSON', { virtuals: true });
module.exports = mongoose.model('Debt', debtSchema);
