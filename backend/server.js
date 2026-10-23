require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const app = express();
app.use(cors());
app.use(express.json());

const { authenticate } = require('./middleware/auth');
const User = require('./models/User');
const { ALL_PERMISSIONS } = require('./permissions');

// تمرير أخطاء الـ async handlers إلى معالج الأخطاء بدل إسقاط العملية
const wrapAsync = (router) => {
  router.stack.forEach(layer => {
    if (!layer.route) return;
    layer.route.stack.forEach(handler => {
      const fn = handler.handle;
      handler.handle = (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
    });
  });
  return router;
};

// المصادقة والصلاحيات: كل مسارات المتجر تتطلب تسجيل دخول
app.use('/api/products', authenticate, wrapAsync(require('./routes/products')));
app.use('/api/units', authenticate, wrapAsync(require('./routes/units')));
app.use('/api/sales', authenticate, wrapAsync(require('./routes/sales')));
app.use('/api/expenses', authenticate, wrapAsync(require('./routes/expenses')));
app.use('/api/inventory', authenticate, wrapAsync(require('./routes/inventory')));
app.use('/api/customers', authenticate, wrapAsync(require('./routes/customers')));
app.use('/api/cashbox', authenticate, wrapAsync(require('./routes/cashbox')));
app.use('/api/users', authenticate, wrapAsync(require('./routes/users')));
app.use('/api/audit', authenticate, wrapAsync(require('./routes/audit')));
app.use('/api/auth', wrapAsync(require('./routes/auth')));
app.use('/api', wrapAsync(require('./routes/rates')));

app.use('/api', (req, res) => res.status(404).json({ error: 'المسار غير موجود' }));

app.use((err, req, res, next) => {
  console.error('API error:', err.message);
  if (res.headersSent) return next(err);
  res.status(err.status || 500).json({ error: err.message || 'خطأ في الخادم' });
});

process.on('unhandledRejection', err => console.error('Unhandled rejection:', err?.message || err));
process.on('uncaughtException', err => console.error('Uncaught exception:', err?.message || err));

// إنشاء حساب الأدمن الأول تلقائياً عند أول تشغيل
async function ensureAdmin() {
  const count = await User.countDocuments();
  if (count > 0) return;
  const username = (process.env.ADMIN_USERNAME || 'admin').toLowerCase();
  const password = process.env.ADMIN_PASSWORD || 'admin123';
  const admin = new User({
    username,
    name: process.env.ADMIN_NAME || 'المدير',
    role: 'admin',
    permissions: ALL_PERMISSIONS,
    active: true,
  });
  await admin.setPassword(password);
  await admin.save();
  console.log(`[auth] تم إنشاء حساب الأدمن: ${username} / ${password}`);
}

// ترحيل الأصناف القديمة: وحدة شراء/بيع + معامل تحويل افتراضي (1)
async function ensureProductUnits() {
  const Product = require('./models/Product');
  const filter = {
    $or: [
      { purchaseUnit: { $exists: false } },
      { saleUnit: { $exists: false } },
      { conversion: { $exists: false } },
    ],
  };
  const legacy = await Product.countDocuments(filter);
  if (!legacy) return;
  await Product.updateMany(filter, [{
    $set: {
      saleUnit: { $ifNull: ['$saleUnit', { $ifNull: ['$unit', 'قطعة'] }] },
      purchaseUnit: { $ifNull: ['$purchaseUnit', { $ifNull: ['$unit', 'قطعة'] }] },
      conversion: { $ifNull: ['$conversion', 1] },
    },
  }]);
  console.log(`[products] تم تجهيز وحدات ${legacy} صنفاً قديماً`);
}

mongoose.connect(process.env.MONGO_URI)
  .then(() => ensureAdmin())
  .then(() => ensureProductUnits())
  .then(() => app.listen(process.env.PORT || 5000, () => console.log(`Running on ${process.env.PORT || 5000}`)))
  .catch(e => { console.error(e); process.exit(1); });
