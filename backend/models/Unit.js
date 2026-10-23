const mongoose = require('mongoose');

// كتالوج وحدات القياس — يديره الأدمن، وتُختار منه وحدات الشراء/البيع للأصناف
const unitSchema = new mongoose.Schema({
  name: { type: String, required: true, unique: true, trim: true },
  note: { type: String, default: '' },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Unit', unitSchema);
