const mongoose = require('mongoose');

// سجل البيع — الربح يُحسب لحظياً بسعر الدولار وقت البيع
const saleSchema = new mongoose.Schema({
  product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  quantity: { type: Number, required: true },
  salePrice: { type: Number, required: true }, // سعر القطعة عند البيع
  purchasePrice: { type: Number, required: true }, // سعر الشراء محفوظ وقت البيع
  purchaseCurrency: { type: String, enum: ['SYP', 'USD'], required: true },
  usdRate: { type: Number, required: true }, // سعر الدولار وقت البيع
  onCredit: { type: Boolean, default: false }, // بيع على الحساب (دين لشخص)
  customer: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer' }, // صاحب الدين عند البيع على الحساب
  date: { type: Date, default: Date.now },
});

// الربح الصافي للقطعة الواحدة بالليرة
saleSchema.virtual('profitPerUnitSYP').get(function () {
  const purchaseSYP = this.purchaseCurrency === 'USD' ? this.purchasePrice * this.usdRate : this.purchasePrice;
  return this.salePrice - purchaseSYP;
});
saleSchema.virtual('totalProfitSYP').get(function () {
  return this.profitPerUnitSYP * this.quantity;
});
// إجمالي قيمة البيع (المبلغ المستلم أو المضاف للدين)
saleSchema.virtual('totalSYP').get(function () {
  return this.salePrice * this.quantity;
});
saleSchema.set('toJSON', { virtuals: true });

module.exports = mongoose.model('Sale', saleSchema);
