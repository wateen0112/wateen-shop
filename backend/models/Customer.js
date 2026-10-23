const mongoose = require('mongoose');

// شخص/زبون — عليه دين للمتجر
const customerSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone: { type: String, default: '' },
  note: { type: String, default: '' },
  initialBalance: { type: Number, default: 0 }, // رصيد مسبق للدين (دين سابق على المتجر)
  createdAt: { type: Date, default: Date.now },
});

customerSchema.set('toJSON', { virtuals: true });
module.exports = mongoose.model('Customer', customerSchema);
