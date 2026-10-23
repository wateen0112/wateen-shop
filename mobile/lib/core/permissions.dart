/// Permission catalogue — mirrors `backend/permissions.js` exactly.
/// Single source of truth for the admin matrix and for every `can(...)` check.
class Permission {
  const Permission(this.key, this.label, this.group);

  final String key;
  final String label;
  final String group;
}

const List<Permission> kPermissions = <Permission>[
  Permission('products.view', 'عرض الأصناف', 'الأصناف والمخزون'),
  Permission('products.edit', 'إضافة وتعديل الأصناف والأسعار', 'الأصناف والمخزون'),
  Permission('barcodes.view', 'عرض الباركودات', 'الأصناف والمخزون'),
  Permission('barcodes.manage', 'توليد وطباعة الباركودات', 'الأصناف والمخزون'),
  Permission('inventory.view', 'عرض الجرد', 'الأصناف والمخزون'),
  Permission('inventory.edit', 'تنفيذ الجرد', 'الأصناف والمخزون'),
  Permission('sales.create', 'إجراء عمليات البيع', 'المبيعات'),
  Permission('debts.view', 'عرض الديون', 'الديون والمالية'),
  Permission('debts.edit', 'إدارة الديون والأشخاص', 'الديون والمالية'),
  Permission('expenses.view', 'عرض المصروفات', 'الديون والمالية'),
  Permission('expenses.edit', 'إضافة وتعديل المصروفات', 'الديون والمالية'),
  Permission('cashbox.view', 'عرض الصندوق', 'الديون والمالية'),
  Permission('cashbox.edit', 'تعديل رصيد الصندوق', 'الديون والمالية'),
  Permission('reports.view', 'عرض الأرباح والملخصات', 'التقارير والإدارة'),
  Permission('users.manage', 'إدارة المستخدمين والصلاحيات', 'التقارير والإدارة'),
];

const List<String> kAllPermissions = <String>[
  'products.view',
  'products.edit',
  'barcodes.view',
  'barcodes.manage',
  'inventory.view',
  'inventory.edit',
  'sales.create',
  'debts.view',
  'debts.edit',
  'expenses.view',
  'expenses.edit',
  'cashbox.view',
  'cashbox.edit',
  'reports.view',
  'users.manage',
];

/// Default permissions applied to a new "user" (mirrors DEFAULT_USER_PERMISSIONS).
const List<String> kDefaultUserPermissions = <String>[
  'products.view',
  'barcodes.view',
  'sales.create',
  'debts.view',
  'expenses.view',
  'cashbox.view',
];

/// Ordered groups of the permission matrix (as shown in the admin UI).
Map<String, List<Permission>> groupPermissions(List<Permission> catalogue) {
  final Map<String, List<Permission>> groups = <String, List<Permission>>{};
  for (final p in catalogue) {
    groups.putIfAbsent(p.group, () => <Permission>[]).add(p);
  }
  return groups;
}

String labelOf(String key) {
  for (final p in kPermissions) {
    if (p.key == key) return p.label;
  }
  return key;
}
