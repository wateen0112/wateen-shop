const express = require('express');
const mongoose = require('mongoose');
const AuditLog = require('../models/AuditLog');
const User = require('../models/User');
const { requireAdmin } = require('../middleware/auth');
const { ACTION_LABELS, ENTITY_LABELS } = require('../audit');

const router = express.Router();

// السجل متاح للأدمن فقط
router.use(requireAdmin);

const escapeRegex = s => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function buildQuery(req) {
  const q = {};
  const { q: search, action, entity, userId, from, to } = req.query;

  if (search && String(search).trim()) {
    const rx = new RegExp(escapeRegex(String(search).trim()), 'i');
    q.$or = [{ summary: rx }, { label: rx }, { username: rx }, { userName: rx }, { entityId: rx }];
  }
  if (action && String(action).trim()) {
    const value = String(action).trim();
    q.action = value.includes('.') ? value : new RegExp(`^${escapeRegex(value)}\\.`, 'i');
  }
  if (entity && ENTITY_LABELS[entity]) q.entity = entity;
  if (userId && mongoose.isValidObjectId(userId)) q.user = userId;

  if (from || to) {
    q.createdAt = {};
    if (from) {
      const d = new Date(from);
      if (!Number.isNaN(d.getTime())) q.createdAt.$gte = d;
    }
    if (to) {
      const d = new Date(to);
      if (!Number.isNaN(d.getTime())) {
        // نهاية اليوم المختار
        if (/^\d{4}-\d{2}-\d{2}$/.test(String(to))) d.setHours(23, 59, 59, 999);
        q.createdAt.$lte = d;
      }
    }
    if (!Object.keys(q.createdAt).length) delete q.createdAt;
  }
  return q;
}

function serialize(doc) {
  return {
    _id: doc._id,
    user: doc.user || null,
    username: doc.username || '',
    name: doc.userName || '',
    role: doc.role || '',
    action: doc.action,
    actionLabel: ACTION_LABELS[doc.action] || doc.action,
    entity: doc.entity,
    entityLabel: ENTITY_LABELS[doc.entity] || doc.entity,
    entityId: doc.entityId || '',
    label: doc.label || '',
    summary: doc.summary,
    details: doc.details === undefined ? null : doc.details,
    ip: doc.ip || '',
    userAgent: doc.userAgent || '',
    createdAt: doc.createdAt,
  };
}

// GET /api/audit — قائمة السجل مع فلاتر وترقيم صفحات
router.get('/', async (req, res) => {
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 50));
  const query = buildQuery(req);

  const [total, docs] = await Promise.all([
    AuditLog.countDocuments(query),
    AuditLog.find(query)
      .sort('-createdAt')
      .skip((page - 1) * limit)
      .limit(limit)
      .lean(),
  ]);

  res.json({
    items: docs.map(serialize),
    total,
    page,
    limit,
    pages: Math.max(1, Math.ceil(total / limit)),
  });
});

// GET /api/audit/meta — خيارات الفلترة (الإجراءات، الأقسام، المستخدمون)
router.get('/meta', async (req, res) => {
  const [byAction, byEntity, users] = await Promise.all([
    AuditLog.aggregate([{ $group: { _id: '$action', count: { $sum: 1 } } }, { $sort: { count: -1 } }]),
    AuditLog.aggregate([{ $group: { _id: '$entity', count: { $sum: 1 } } }, { $sort: { count: -1 } }]),
    User.find().select('username name role active').sort('username').lean(),
  ]);

  res.json({
    actions: byAction.map(a => ({
      key: a._id,
      label: ACTION_LABELS[a._id] || a._id,
      count: a.count,
    })),
    entities: byEntity.map(e => ({
      key: e._id,
      label: ENTITY_LABELS[e._id] || e._id,
      count: e.count,
    })),
    users: users.map(u => ({
      _id: u._id,
      username: u.username,
      name: u.name || '',
      role: u.role,
      active: u.active,
    })),
  });
});

// GET /api/audit/export.csv — تصدير النتائج المفلترة إلى CSV (متوافق مع Excel)
router.get('/export.csv', async (req, res) => {
  const query = buildQuery(req);
  const docs = await AuditLog.find(query).sort('-createdAt').limit(5000).lean();

  const headers = ['التاريخ', 'المستخدم', 'الاسم', 'الدور', 'الإجراء', 'القسم', 'العنصر', 'التفاصيل', 'IP'];
  const cell = v => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const rows = docs.map(d => [
    new Date(d.createdAt).toLocaleString('ar-SY'),
    d.username || '',
    d.userName || '',
    d.role === 'admin' ? 'أدمن' : 'مستخدم',
    ACTION_LABELS[d.action] || d.action,
    ENTITY_LABELS[d.entity] || d.entity,
    d.label || '',
    d.summary,
    d.ip || '',
  ].map(cell).join(','));

  const csv = '\uFEFF' + [headers.map(cell).join(','), ...rows].join('\r\n');
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename="audit-log.csv"');
  res.send(csv);
});

// GET /api/audit/:id — تفاصيل عملية واحدة
router.get('/:id', async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) {
    return res.status(404).json({ error: 'العملية غير موجودة' });
  }
  const doc = await AuditLog.findById(req.params.id).lean();
  if (!doc) return res.status(404).json({ error: 'العملية غير موجودة' });
  res.json(serialize(doc));
});

module.exports = router;
