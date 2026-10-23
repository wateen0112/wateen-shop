const mongoose = require('mongoose');

// الصندوق — وثيقة واحدة تحمل الرصيد الابتدائي
const cashboxSchema = new mongoose.Schema({
  key: { type: String, default: 'main', unique: true },
  initialBalance: { type: Number, default: 0 },
  updatedAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Cashbox', cashboxSchema);
