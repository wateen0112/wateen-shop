const mongoose = require('mongoose');

// سجل العمليات — يُخزّن كل إجراء يقوم به مستخدم مع لقطة عن هويته
// (نحفظ الاسم واسم المستخدم كنص حتى لا يتأثر السجل بحذف الحساب لاحقاً)
const auditLogSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
  username: { type: String, default: '' },
  userName: { type: String, default: '' },
  role: { type: String, default: '' },

  action: { type: String, required: true, index: true },
  entity: { type: String, required: true, index: true },
  entityId: { type: String, default: '' },
  label: { type: String, default: '' },

  summary: { type: String, required: true },
  details: { type: mongoose.Schema.Types.Mixed, default: undefined },

  ip: { type: String, default: '' },
  userAgent: { type: String, default: '' },
  createdAt: { type: Date, default: Date.now, index: true },
});

auditLogSchema.index({ createdAt: -1 });
auditLogSchema.index({ summary: 'text', label: 'text', username: 'text' });

module.exports = mongoose.model('AuditLog', auditLogSchema);
