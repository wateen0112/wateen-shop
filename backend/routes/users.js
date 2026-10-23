const express = require('express');
const User = require('../models/User');
const { requireAdmin } = require('../middleware/auth');
const { PERMISSIONS, ALL_PERMISSIONS, DEFAULT_USER_PERMISSIONS } = require('../permissions');
const { audit, diff, describeChanges, roleLabel } = require('../audit');
const router = express.Router();

// كل مسارات المستخدمين للأدمن فقط
router.use(requireAdmin);

// قائمة المستخدمين
router.get('/', async (req, res) => {
  const users = await User.find().sort('createdAt');
  res.json(users.map(u => u.toSafe()));
});

// إضافة مستخدم جديد مع صلاحياته
router.post('/', async (req, res) => {
  try {
    const { username, password, name, role, permissions } = req.body || {};
    const clean = String(username || '').toLowerCase().trim();
    if (!clean) return res.status(400).json({ error: 'أدخل اسم المستخدم' });
    if (!password || String(password).length < 4) {
      return res.status(400).json({ error: 'كلمة المرور يجب أن تكون 4 أحرف على الأقل' });
    }
    const exists = await User.findOne({ username: clean });
    if (exists) return res.status(400).json({ error: 'اسم المستخدم مستخدم مسبقاً' });

    const isAdmin = role === 'admin';
    const perms = isAdmin
      ? ALL_PERMISSIONS
      : (Array.isArray(permissions) && permissions.length ? permissions : DEFAULT_USER_PERMISSIONS);

    const user = new User({
      username: clean,
      name: name || '',
      role: isAdmin ? 'admin' : 'user',
      permissions: perms.filter(p => ALL_PERMISSIONS.includes(p)),
      active: true,
    });
    await user.setPassword(String(password));
    await user.save();
    await audit(req, {
      action: 'user.create',
      entity: 'user',
      entityId: user._id,
      label: user.username,
      summary: `أنشأ المستخدم «${user.username}»` +
        (user.name ? ` (${user.name})` : '') +
        ` — ${user.role === 'admin' ? 'أدمن' : `مستخدم بصلاحيات ${user.permissions.length}`}`,
      details: {
        username: user.username,
        name: user.name,
        role: user.role,
        permissions: user.permissions,
      },
    });
    res.status(201).json(user.toSafe());
  } catch (e) {
    res.status(400).json({ error: e.code === 11000 ? 'اسم المستخدم مستخدم مسبقاً' : e.message });
  }
});

// تعديل مستخدم (الاسم، الصلاحيات، التفعيل، كلمة المرور)
router.put('/:id', async (req, res) => {
  try {
    const before = await User.findById(req.params.id).lean();
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'المستخدم غير موجود' });

    const { name, role, permissions, active, password } = req.body || {};
    if (name !== undefined) user.name = name;
    if (role !== undefined && role !== user.role) {
      if (user.role === 'admin') {
        const admins = await User.countDocuments({ role: 'admin', active: true });
        if (admins <= 1) return res.status(400).json({ error: 'لا يمكن تغيير دور آخر أدمن في النظام' });
      }
      user.role = role === 'admin' ? 'admin' : 'user';
    }
    if (Array.isArray(permissions)) {
      user.permissions = permissions.filter(p => ALL_PERMISSIONS.includes(p));
    }
    if (active !== undefined) {
      if (!active && user.role === 'admin') {
        const admins = await User.countDocuments({ role: 'admin', active: true });
        if (admins <= 1) return res.status(400).json({ error: 'لا يمكن تعطيل آخر أدمن' });
      }
      user.active = !!active;
    }
    if (password) {
      if (String(password).length < 4) return res.status(400).json({ error: 'كلمة المرور قصيرة جداً' });
      await user.setPassword(String(password));
    }
    await user.save();
    const changes = diff(before, user.toObject(), ['name', 'role', 'active', 'permissions']);
    const parts = [];
    for (const c of changes) {
      if (c.field === 'role') parts.push(`الدور ${roleLabel(c.from)} ← ${roleLabel(c.to)}`);
      else if (c.field === 'active') parts.push(c.to ? 'تم التفعيل' : 'تم التعطيل');
      else if (c.field === 'permissions') parts.push(`الصلاحيات ${Array.isArray(c.from) ? c.from.length : 0} ← ${Array.isArray(c.to) ? c.to.length : 0}`);
      else if (c.field === 'name') parts.push(`الاسم ${c.from || '(فارغ)'} ← ${c.to || '(فارغ)'}`);
    }
    if (password) parts.push('تغيير كلمة المرور');
    await audit(req, {
      action: 'user.update',
      entity: 'user',
      entityId: user._id,
      label: user.username,
      summary: parts.length
        ? `عدّل المستخدم «${user.username}»: ${parts.join('، ')}`
        : `حفظ المستخدم «${user.username}» دون تغييرات فعلية`,
      details: { changes, passwordChanged: !!password },
    });
    res.json(user.toSafe());
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

// حذف مستخدم
router.delete('/:id', async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) return res.status(404).json({ error: 'المستخدم غير موجود' });
  if (String(user._id) === String(req.user._id)) {
    return res.status(400).json({ error: 'لا يمكنك حذف حسابك الحالي' });
  }
  if (user.role === 'admin') {
    const admins = await User.countDocuments({ role: 'admin' });
    if (admins <= 1) return res.status(400).json({ error: 'لا يمكن حذف آخر أدمن' });
  }
  await User.findByIdAndDelete(req.params.id);
  await audit(req, {
    action: 'user.delete',
    entity: 'user',
    entityId: user._id,
    label: user.username,
    summary: `حذف المستخدم «${user.username}»` + (user.name ? ` (${user.name})` : ''),
    details: {
      username: user.username,
      name: user.name,
      role: user.role,
      permissions: user.permissions,
    },
  });
  res.json({ ok: true });
});

module.exports = router;
