const express = require('express');
const User = require('../models/User');
const { authenticate, signToken } = require('../middleware/auth');
const { PERMISSIONS } = require('../permissions');
const { audit } = require('../audit');
const router = express.Router();

// كتالوج الصلاحيات (متاح قبل تسجيل الدخول لبناء واجهة الأدمن)
router.get('/permissions', (req, res) => res.json(PERMISSIONS));

// تسجيل الدخول
router.post('/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'أدخل اسم المستخدم وكلمة المرور' });

  const clean = String(username).toLowerCase().trim();
  const user = await User.findOne({ username: clean });
  if (!user || !(await user.checkPassword(password))) {
    await audit(req, {
      action: 'login.failed',
      entity: 'auth',
      username: clean,
      label: clean,
      summary: `محاولة دخول فاشلة باسم «${clean}» — اسم مستخدم أو كلمة مرور غير صحيحة`,
      details: { reason: 'bad_credentials' },
    });
    return res.status(401).json({ error: 'اسم المستخدم أو كلمة المرور غير صحيحة' });
  }
  if (!user.active) {
    await audit(req, {
      action: 'login.failed',
      entity: 'auth',
      username: user.username,
      role: user.role,
      label: user.username,
      summary: `محاولة دخول فاشلة باسم «${user.username}» — الحساب معطّل`,
      details: { reason: 'inactive', userName: user.name },
    });
    return res.status(403).json({ error: 'هذا الحساب معطّل — راجع الأدمن' });
  }

  await audit(req, {
    action: 'login',
    entity: 'auth',
    user: user._id,
    username: user.username,
    userName: user.name || '',
    role: user.role,
    label: user.username,
    summary: `سجّل الدخول إلى النظام`,
    details: { userName: user.name, role: user.role },
  });
  res.json({ token: signToken(user), user: user.toSafe() });
});

// تسجيل الخروج (التوكن بلا حالة — نسجّل الحدث فقط)
router.post('/logout', authenticate, async (req, res) => {
  await audit(req, {
    action: 'logout',
    entity: 'auth',
    label: req.user.username,
    summary: 'سجّل الخروج من النظام',
  });
  res.json({ ok: true });
});

// بيانات المستخدم الحالي
router.get('/me', authenticate, (req, res) => res.json(req.user.toSafe()));

// تغيير كلمة المرور
router.post('/change-password', authenticate, async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (!newPassword || String(newPassword).length < 4) {
    return res.status(400).json({ error: 'كلمة المرور الجديدة قصيرة جداً (4 أحرف على الأقل)' });
  }
  const user = await User.findById(req.user._id);
  if (!(await user.checkPassword(currentPassword || ''))) {
    return res.status(400).json({ error: 'كلمة المرور الحالية غير صحيحة' });
  }
  await user.setPassword(newPassword);
  await user.save();
  await audit(req, {
    action: 'password.change',
    entity: 'auth',
    label: user.username,
    summary: 'غيّر كلمة المرور الخاصة بحسابه',
  });
  res.json({ ok: true });
});

module.exports = router;
