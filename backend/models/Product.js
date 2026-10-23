const mongoose = require('mongoose');

// سجلات أسعار البيع — القطعة ممكن يكون لها أكثر من سعر بيع حسب السوق
const salePriceSchema = new mongoose.Schema({
  price: { type: Number, required: true },
  note: { type: String, default: '' },
  date: { type: Date, default: Date.now },
}, { _id: true });

const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  barcode: { type: String, unique: true, sparse: true }, // null = منتج بدون باركود (بينتظر توليد واحد)
  unit: { type: String, required: true, default: 'قطعة' }, // وحدة البيع (للتوافق مع البيانات القديمة)
  purchaseUnit: { type: String, default: 'قطعة' }, // وحدة الشراء (كرتون/كيس…)
  saleUnit: { type: String, default: 'قطعة' }, // وحدة البيع (قطعة/علبة…)
  conversion: { type: Number, default: 1, min: 0.0001 }, // كم وحدة بيع في وحدة شراء واحدة
  quantity: { type: Number, default: 0 }, // المخزون بوحدات البيع
  purchasePrice: { type: Number, required: true }, // سعر وحدة الشراء الواحدة
  purchaseCurrency: { type: String, enum: ['SYP', 'USD'], default: 'SYP' },
  salePrices: [salePriceSchema], // آخر سعر هو الحالي
  createdAt: { type: Date, default: Date.now },
});

productSchema.virtual('currentSalePrice').get(function () {
  const prices = this.salePrices || [];
  return prices.length ? prices[prices.length - 1].price : null;
});

// معامل التحويل الفعّال (1 إن لم يُحدَّد)
productSchema.virtual('conversionFactor').get(function () {
  const c = Number(this.conversion);
  return Number.isFinite(c) && c > 0 ? c : 1;
});

// تكلفة وحدة البيع الواحدة = سعر وحدة الشراء ÷ معامل التحويل
productSchema.virtual('unitCost').get(function () {
  const price = Number(this.purchasePrice);
  if (!Number.isFinite(price)) return null;
  return price / this.conversionFactor;
});

// تكلفة الكمية كلها (بوحدات الشراء) = التكلفة للوحدة × المخزون
productSchema.virtual('stockCost').get(function () {
  const cost = this.unitCost;
  return cost === null ? null : cost * Number(this.quantity || 0);
});

productSchema.set('toJSON', { virtuals: true });
module.exports = mongoose.model('Product', productSchema);
