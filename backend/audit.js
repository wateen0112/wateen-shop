const AuditLog = require('./models/AuditLog');

// تسميات عربية للإجراءات والأقسام — تُستخدم في السجل وفي واجهة الفلترة
const ACTION_LABELS = {
  'login': 'تسجيل دخول',
  'login.failed': 'محاولة دخول فاشلة',
  'logout': 'تسجيل خروج',
  'password.change': 'تغيير كلمة المرور',
  'product.create': 'إضافة صنف',
  'product.update': 'تعديل صنف',
  'product.delete': 'حذف صنف',
  'product.price_add': 'إضافة سعر بيع',
  'product.barcode_generate': 'توليد باركودات',
  'sale.create': 'عملية بيع',
  'expense.create': 'إضافة مصروف',
  'expense.delete': 'حذف مصروف',
  'inventory.create': 'جرد',
  'customer.create': 'إضافة زبون',
  'customer.update': 'تعديل زبون',
  'customer.delete': 'حذف زبون',
  'debt.create': 'تسجيل دين',
  'debt.delete': 'حذف حركة دين',
  'cashbox.update': 'تعديل الصندوق',
  'user.create': 'إضافة مستخدم',
  'user.update': 'تعديل مستخدم',
  'user.delete': 'حذف مستخدم',
  'unit.create': 'إضافة وحدة قياس',
  'unit.update': 'تعديل وحدة قياس',
  'unit.delete': 'حذف وحدة قياس',
};

const ENTITY_LABELS = {
  auth: 'الحساب',
  product: 'الأصناف',
  sale: 'المبيعات',
  expense: 'المصروفات',
  inventory: 'الجرد',
  customer: 'الزبائن',
  debt: 'الديون',
  cashbox: 'الصندوق',
  user: 'المستخدمون',
  unit: 'وحدات القياس',
};

const FIELD_LABELS = {
  name: 'الاسم',
  barcode: 'الباركود',
  unit: 'الوحدة',
  purchaseUnit: 'وحدة الشراء',
  saleUnit: 'وحدة البيع',
  conversion: 'معامل التحويل',
  quantity: 'الكمية',
  purchasePrice: 'سعر الشراء',
  purchaseCurrency: 'عملة الشراء',
  phone: 'الهاتف',
  note: 'الملاحظة',
  initialBalance: 'الرصيد الافتتاحي',
  role: 'الدور',
  active: 'الحالة',
  permissions: 'الصلاحيات',
  title: 'الاسم',
  amount: 'المبلغ',
  currency: 'العملة',
};

const CURRENCY_LABELS = { SYP: 'ل.س', USD: 'دولار' };

function fmtNum(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return String(value ?? '');
  try {
    return n.toLocaleString('ar-SY', { maximumFractionDigits: 2 });
  } catch {
    return n.toLocaleString('en-US', { maximumFractionDigits: 2 });
  }
}

function money(amount, currency = 'SYP') {
  return `${fmtNum(amount)} ${CURRENCY_LABELS[currency] || currency}`;
}

function roleLabel(role) {
  return role === 'admin' ? 'أدمن' : 'مستخدم';
}

// يقارن حقولاً قبل/بعد ويعيد قائمة تغييرات عربية
function diff(before, after, fields) {
  const out = [];
  for (const field of fields) {
    const from = before ? before[field] : undefined;
    const to = after ? after[field] : undefined;
    const same = Array.isArray(from) || Array.isArray(to)
      ? JSON.stringify(from || []) === JSON.stringify(to || [])
      : String(from ?? '') === String(to ?? '');
    if (same) continue;
    out.push({ field, label: FIELD_LABELS[field] || field, from, to });
  }
  return out;
}

// يحوّل التغييرات إلى جملة عربية: «الكمية» من ٥ إلى ٧، «الاسم» من ...
function describeChanges(changes) {
  if (!changes || !changes.length) return '';
  return changes
    .map(c => {
      const from = Array.isArray(c.from) ? c.from.length : c.from;
      const to = Array.isArray(c.to) ? c.to.length : c.to;
      if (c.field === 'permissions') {
        return `الصلاحيات من ${fmtNum(from || 0)} إلى ${fmtNum(to || 0)}`;
      }
      if (c.field === 'active') {
        return `الحالة من «${from ? 'مفعّل' : 'معطّل'}» إلى «${to ? 'مفعّل' : 'معطّل'}»`;
      }
      if (c.field === 'role') {
        return `الدور من «${roleLabel(from)}» إلى «${roleLabel(to)}»`;
      }
      if (c.field === 'purchaseCurrency' || c.field === 'currency') {
        return `${c.label} من «${CURRENCY_LABELS[from] || from}» إلى «${CURRENCY_LABELS[to] || to}»`;
      }
      const empty = v => v === undefined || v === null || v === '';
      return `${c.label} من «${empty(from) ? '—' : from}» إلى «${empty(to) ? '—' : to}»`;
    })
    .join('، ');
}

function clientIp(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  return forwarded || req.ip || '';
}

// يسجّل العملية ولا يعطّل الطلب إذا فشل التسجيل
async function audit(req, entry) {
  try {
    await AuditLog.create({
      user: entry.user !== undefined ? entry.user : (req.user ? req.user._id : undefined),
      username: entry.username !== undefined ? entry.username : (req.user ? req.user.username : ''),
      userName: entry.userName !== undefined ? entry.userName : (req.user ? (req.user.name || '') : ''),
      role: entry.role !== undefined ? entry.role : (req.user ? req.user.role : ''),
      action: entry.action,
      entity: entry.entity,
      entityId: entry.entityId ? String(entry.entityId) : '',
      label: entry.label || '',
      summary: entry.summary,
      details: entry.details,
      ip: clientIp(req),
      userAgent: String(req.headers['user-agent'] || '').slice(0, 300),
    });
  } catch (e) {
    console.error('[audit] فشل تسجيل العملية:', e.message);
  }
}

module.exports = {
  audit,
  diff,
  describeChanges,
  money,
  fmtNum,
  roleLabel,
  ACTION_LABELS,
  ENTITY_LABELS,
  FIELD_LABELS,
  CURRENCY_LABELS,
};
