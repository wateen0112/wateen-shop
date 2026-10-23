// كتالوج الصلاحيات — مصدر واحد للـ backend والـ frontend
const PERMISSIONS = [
  { key: 'products.view', label: 'عرض الأصناف', group: 'الأصناف والمخزون' },
  { key: 'products.edit', label: 'إضافة وتعديل الأصناف والأسعار', group: 'الأصناف والمخزون' },
  { key: 'barcodes.view', label: 'عرض الباركودات', group: 'الأصناف والمخزون' },
  { key: 'barcodes.manage', label: 'توليد وطباعة الباركودات', group: 'الأصناف والمخزون' },
  { key: 'inventory.view', label: 'عرض الجرد', group: 'الأصناف والمخزون' },
  { key: 'inventory.edit', label: 'تنفيذ الجرد', group: 'الأصناف والمخزون' },
  { key: 'sales.create', label: 'إجراء عمليات البيع', group: 'المبيعات' },
  { key: 'debts.view', label: 'عرض الديون', group: 'الديون والمالية' },
  { key: 'debts.edit', label: 'إدارة الديون والأشخاص', group: 'الديون والمالية' },
  { key: 'expenses.view', label: 'عرض المصروفات', group: 'الديون والمالية' },
  { key: 'expenses.edit', label: 'إضافة وتعديل المصروفات', group: 'الديون والمالية' },
  { key: 'cashbox.view', label: 'عرض الصندوق', group: 'الديون والمالية' },
  { key: 'cashbox.edit', label: 'تعديل رصيد الصندوق', group: 'الديون والمالية' },
  { key: 'reports.view', label: 'عرض الأرباح والملخصات', group: 'التقارير والإدارة' },
  { key: 'users.manage', label: 'إدارة المستخدمين والصلاحيات', group: 'التقارير والإدارة' },
];

const ALL_PERMISSIONS = PERMISSIONS.map(p => p.key);

// صلاحيات افتراضية لمستخدم عادي (بدون صلاحيات إدارية)
const DEFAULT_USER_PERMISSIONS = [
  'products.view', 'barcodes.view', 'sales.create',
  'debts.view', 'expenses.view', 'cashbox.view',
];

module.exports = { PERMISSIONS, ALL_PERMISSIONS, DEFAULT_USER_PERMISSIONS };
