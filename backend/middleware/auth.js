const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { ALL_PERMISSIONS } = require('../permissions');

const JWT_SECRET = process.env.JWT_SECRET || 'wateen-shop-change-me-secret';
const TOKEN_TTL = '30d';

function signToken(user) {
  return jwt.sign({ sub: String(user._id), role: user.role }, JWT_SECRET, { expiresIn: TOKEN_TTL });
}

// التحقق من التوكن + تحميل المستخدم
async function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : null;
  if (!token) return res.status(401).json({ error: 'يجب تسجيل الدخول' });

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(payload.sub);
    if (!user) return res.status(401).json({ error: 'الحساب غير موجود' });
    if (!user.active) return res.status(403).json({ error: 'هذا الحساب معطّل — راجع الأدمن' });
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'انتهت الجلسة، سجّل الدخول من جديد' });
  }
}

// التحقق من صلاحية واحدة أو أكثر (الأدمن يملك كل الصلاحيات)
function requirePerm(...keys) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'يجب تسجيل الدخول' });
    if (req.user.role === 'admin') return next();
    if (keys.some(k => req.user.permissions.includes(k))) return next();
    return res.status(403).json({ error: 'لا تملك صلاحية لهذا الإجراء' });
  };
}

// الأدمن فقط
function requireAdmin(req, res, next) {
  if (!req.user) return res.status(401).json({ error: 'يجب تسجيل الدخول' });
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'هذه الصفحة للأدمن فقط' });
  next();
}

module.exports = { authenticate, requirePerm, requireAdmin, signToken, ALL_PERMISSIONS };
