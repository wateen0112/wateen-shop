const mongoose = require('mongoose');

// جرد كامل: snapshot للكميات الفعلية، والفرق بين الفعلي والمسجل
const inventorySchema = new mongoose.Schema({
  items: [{
    product: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
    name: String,
    recordedQty: Number, // الكمية بالنظام
    actualQty: { type: Number, required: true }, // الكمية الفعلية بعد العدّ
  }],
  note: { type: String, default: '' },
  date: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Inventory', inventorySchema);
