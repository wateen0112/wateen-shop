/// Data models — mirror the Mongoose schemas of `backend/models/*.js`
/// (including the virtuals `currentSalePrice`, `totalSYP`, `profitPerUnitSYP`).
library;

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _toInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _toDate(Object? value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is DateTime) return value.toLocal();
  return null;
}

String _toStr(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

// ---------------------------------------------------------------------------
// User
// ---------------------------------------------------------------------------

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.permissions,
    required this.active,
    this.createdAt,
  });

  final String id;
  final String username;
  final String name;
  final String role;
  final List<String> permissions;
  final bool active;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';

  bool can(String key) => isAdmin || permissions.contains(key);

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: _toStr(json['_id'] ?? json['id']),
        username: _toStr(json['username']),
        name: _toStr(json['name']),
        role: _toStr(json['role'], 'user'),
        permissions: ((json['permissions'] as List?) ?? const <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
        active: json['active'] != false,
        createdAt: _toDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        '_id': id,
        'username': username,
        'name': name,
        'role': role,
        'permissions': permissions,
        'active': active,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Product
// ---------------------------------------------------------------------------

class SalePrice {
  const SalePrice({required this.price, this.note = '', this.date});

  final double price;
  final String note;
  final DateTime? date;

  factory SalePrice.fromJson(Map<String, dynamic> json) => SalePrice(
        price: _toDouble(json['price']),
        note: _toStr(json['note']),
        date: _toDate(json['date']),
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.unit,
    required this.quantity,
    required this.purchasePrice,
    required this.purchaseCurrency,
    required this.salePrices,
    this.createdAt,
  });

  final String id;
  final String name;
  final String barcode;
  final String unit;
  final double quantity;
  final double purchasePrice;
  final String purchaseCurrency;
  final List<SalePrice> salePrices;
  final DateTime? createdAt;

  /// Virtual `currentSalePrice` — the last price in the history.
  double? get currentSalePrice =>
      salePrices.isEmpty ? null : salePrices.last.price;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: _toStr(json['_id'] ?? json['id']),
        name: _toStr(json['name']),
        barcode: _toStr(json['barcode']),
        unit: _toStr(json['unit']),
        quantity: _toDouble(json['quantity']),
        purchasePrice: _toDouble(json['purchasePrice']),
        purchaseCurrency: _toStr(json['purchaseCurrency'], 'SYP'),
        salePrices: ((json['salePrices'] as List?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(SalePrice.fromJson)
            .toList(),
        createdAt: _toDate(json['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// Sale
// ---------------------------------------------------------------------------

class Sale {
  const Sale({
    required this.id,
    required this.product,
    required this.quantity,
    required this.salePrice,
    required this.purchasePrice,
    required this.purchaseCurrency,
    required this.usdRate,
    required this.onCredit,
    required this.customer,
    required this.date,
    required this.totalSYP,
    required this.profitPerUnitSYP,
    required this.totalProfitSYP,
  });

  final String id;
  final String product;
  final double quantity;
  final double salePrice;
  final double purchasePrice;
  final String purchaseCurrency;
  final double usdRate;
  final bool onCredit;
  final String customer;
  final DateTime? date;
  final double totalSYP;
  final double profitPerUnitSYP;
  final double totalProfitSYP;

  factory Sale.fromJson(Map<String, dynamic> json) {
    final double purchasePrice = _toDouble(json['purchasePrice']);
    final double usdRate = _toDouble(json['usdRate']);
    final String currency = _toStr(json['purchaseCurrency'], 'SYP');
    final double purchaseSYP = currency == 'USD' ? purchasePrice * usdRate : purchasePrice;
    final double salePrice = _toDouble(json['salePrice']);
    final double quantity = _toDouble(json['quantity']);
    return Sale(
      id: _toStr(json['_id'] ?? json['id']),
      product: _toStr(json['product']),
      quantity: quantity,
      salePrice: salePrice,
      purchasePrice: purchasePrice,
      purchaseCurrency: currency,
      usdRate: usdRate,
      onCredit: json['onCredit'] == true,
      customer: _toStr(json['customer']),
      date: _toDate(json['date']),
      totalSYP: _toDouble(json['totalSYP']) == 0
          ? salePrice * quantity
          : _toDouble(json['totalSYP']),
      profitPerUnitSYP:
          _toDouble(json['profitPerUnitSYP']) == 0 ? salePrice - purchaseSYP : _toDouble(json['profitPerUnitSYP']),
      totalProfitSYP: _toDouble(json['totalProfitSYP']) == 0
          ? (salePrice - purchaseSYP) * quantity
          : _toDouble(json['totalProfitSYP']),
    );
  }
}

// ---------------------------------------------------------------------------
// Expense
// ---------------------------------------------------------------------------

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.date,
    required this.note,
  });

  final String id;
  final String title;
  final double amount;
  final String currency;
  final DateTime? date;
  final String note;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: _toStr(json['_id'] ?? json['id']),
        title: _toStr(json['title']),
        amount: _toDouble(json['amount']),
        currency: _toStr(json['currency'], 'SYP'),
        date: _toDate(json['date']),
        note: _toStr(json['note']),
      );
}

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

class InventoryItem {
  const InventoryItem({
    required this.product,
    required this.name,
    required this.recordedQty,
    required this.actualQty,
  });

  final String product;
  final String name;
  final double recordedQty;
  final double actualQty;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        product: _toStr(json['product']),
        name: _toStr(json['name']),
        recordedQty: _toDouble(json['recordedQty']),
        actualQty: _toDouble(json['actualQty']),
      );
}

class InventorySnapshot {
  const InventorySnapshot({
    required this.id,
    required this.items,
    required this.note,
    required this.date,
  });

  final String id;
  final List<InventoryItem> items;
  final String note;
  final DateTime? date;

  factory InventorySnapshot.fromJson(Map<String, dynamic> json) =>
      InventorySnapshot(
        id: _toStr(json['_id'] ?? json['id']),
        items: ((json['items'] as List?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(InventoryItem.fromJson)
            .toList(),
        note: _toStr(json['note']),
        date: _toDate(json['date']),
      );
}

/// A row of the inventory sheet (a product with its counted quantity).
class SheetRow {
  SheetRow({required this.product, required this.name, required this.unit, required this.quantity});

  final Product product;
  final String name;
  final String unit;
  double quantity;

  factory SheetRow.fromProduct(Product product) => SheetRow(
        product: product,
        name: product.name,
        unit: product.unit,
        quantity: product.quantity,
      );
}

// ---------------------------------------------------------------------------
// Customers & debts
// ---------------------------------------------------------------------------

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.note,
    required this.initialBalance,
    required this.balance,
    this.movements = const <DebtMovement>[],
  });

  final String id;
  final String name;
  final String phone;
  final String note;
  final double initialBalance;
  final double balance;
  final List<DebtMovement> movements;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: _toStr(json['_id'] ?? json['id']),
        name: _toStr(json['name']),
        phone: _toStr(json['phone']),
        note: _toStr(json['note']),
        initialBalance: _toDouble(json['initialBalance']),
        balance: _toDouble(json['balance']),
        movements: ((json['movements'] as List?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(DebtMovement.fromJson)
            .toList(),
      );
}

class DebtMovement {
  const DebtMovement({
    required this.id,
    required this.customer,
    required this.type,
    required this.amount,
    required this.note,
    required this.source,
    required this.sale,
    required this.date,
  });

  final String id;
  final String customer;
  final String type;
  final double amount;
  final String note;
  final String source;
  final String sale;
  final DateTime? date;

  bool get isDebit => type == 'debit';

  factory DebtMovement.fromJson(Map<String, dynamic> json) => DebtMovement(
        id: _toStr(json['_id'] ?? json['id']),
        customer: _toStr(json['customer']),
        type: _toStr(json['type']),
        amount: _toDouble(json['amount']),
        note: _toStr(json['note']),
        source: _toStr(json['source'], 'manual'),
        sale: _toStr(json['sale']),
        date: _toDate(json['date']),
      );
}

// ---------------------------------------------------------------------------
// Cash box & profit
// ---------------------------------------------------------------------------

class CashboxSummary {
  const CashboxSummary({
    this.initialBalance = 0,
    this.salesCash = 0,
    this.salesCredit = 0,
    this.salesProfit = 0,
    this.expensesTotal = 0,
    this.current = 0,
    this.netProfit = 0,
    this.debtsTotal = 0,
    this.salesCount = 0,
  });

  final double initialBalance;
  final double salesCash;
  final double salesCredit;
  final double salesProfit;
  final double expensesTotal;
  final double current;
  final double netProfit;
  final double debtsTotal;
  final int salesCount;

  factory CashboxSummary.fromJson(Map<String, dynamic> json) => CashboxSummary(
        initialBalance: _toDouble(json['initialBalance']),
        salesCash: _toDouble(json['salesCash']),
        salesCredit: _toDouble(json['salesCredit']),
        salesProfit: _toDouble(json['salesProfit']),
        expensesTotal: _toDouble(json['expensesTotal']),
        current: _toDouble(json['current']),
        netProfit: _toDouble(json['netProfit']),
        debtsTotal: _toDouble(json['debtsTotal']),
        salesCount: _toInt(json['salesCount']),
      );
}

class ProfitSummary {
  const ProfitSummary({this.totalProfitSYP = 0, this.salesCount = 0});

  final double totalProfitSYP;
  final int salesCount;

  factory ProfitSummary.fromJson(Map<String, dynamic> json) => ProfitSummary(
        totalProfitSYP: _toDouble(json['totalProfitSYP']),
        salesCount: _toInt(json['salesCount']),
      );
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

class BarcodeResult {
  const BarcodeResult({required this.id, required this.name, required this.barcode, required this.generated});

  final String id;
  final String name;
  final String barcode;
  final bool generated;

  factory BarcodeResult.fromJson(Map<String, dynamic> json) => BarcodeResult(
        id: _toStr(json['id'] ?? json['_id']),
        name: _toStr(json['name']),
        barcode: _toStr(json['barcode']),
        generated: json['generated'] == true,
      );
}

class RateInfo {
  const RateInfo({required this.rate, required this.source});

  /// SYP per 1 USD — the backend returns it as `usdToSyp`.
  final double rate;
  final String source;

  bool get isConfigured => rate > 0;

  factory RateInfo.fromJson(Map<String, dynamic> json) => RateInfo(
        rate: _toDouble(json['usdToSyp']),
        source: _toStr(json['source'], 'not-configured'),
      );
}
// ---------------------------------------------------------------------------
// Audit log (سجل العمليات)
// ---------------------------------------------------------------------------

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.action,
    required this.actionLabel,
    required this.entity,
    required this.entityLabel,
    required this.entityId,
    required this.label,
    required this.summary,
    required this.details,
    required this.ip,
    this.createdAt,
  });

  final String id;
  final String username;
  final String name;
  final String role;
  final String action;
  final String actionLabel;
  final String entity;
  final String entityLabel;
  final String entityId;
  final String label;
  final String summary;
  final Map<String, dynamic>? details;
  final String ip;
  final DateTime? createdAt;

  bool get isAdminAction => role == 'admin';

  String get actorLabel => name.isNotEmpty ? name : username;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: _toStr(json['_id'] ?? json['id']),
        username: _toStr(json['username']),
        name: _toStr(json['name']),
        role: _toStr(json['role']),
        action: _toStr(json['action']),
        actionLabel: _toStr(json['actionLabel']),
        entity: _toStr(json['entity']),
        entityLabel: _toStr(json['entityLabel']),
        entityId: _toStr(json['entityId']),
        label: _toStr(json['label']),
        summary: _toStr(json['summary']),
        details: json['details'] is Map
            ? Map<String, dynamic>.from(json['details'] as Map)
            : null,
        ip: _toStr(json['ip']),
        createdAt: _toDate(json['createdAt']),
      );
}

class AuditOption {
  const AuditOption({required this.key, required this.label, required this.count});

  final String key;
  final String label;
  final int count;

  factory AuditOption.fromJson(Map<String, dynamic> json) => AuditOption(
        key: _toStr(json['key']),
        label: _toStr(json['label'], _toStr(json['key'])),
        count: _toInt(json['count']),
      );
}

class AuditUserOption {
  const AuditUserOption({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.active,
  });

  final String id;
  final String username;
  final String name;
  final String role;
  final bool active;

  String get label => name.isNotEmpty ? name : username;

  factory AuditUserOption.fromJson(Map<String, dynamic> json) => AuditUserOption(
        id: _toStr(json['_id'] ?? json['id']),
        username: _toStr(json['username']),
        name: _toStr(json['name']),
        role: _toStr(json['role']),
        active: json['active'] != false,
      );
}

class AuditMeta {
  const AuditMeta({required this.actions, required this.entities, required this.users});

  final List<AuditOption> actions;
  final List<AuditOption> entities;
  final List<AuditUserOption> users;

  factory AuditMeta.fromJson(Map<String, dynamic> json) => AuditMeta(
        actions: ((json['actions'] as List?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AuditOption.fromJson)
            .toList(),
        entities: ((json['entities'] as List?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AuditOption.fromJson)
            .toList(),
        users: ((json['users'] as List?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AuditUserOption.fromJson)
            .toList(),
      );
}

class AuditPage {
  const AuditPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  final List<AuditEntry> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  bool get hasMore => page < pages;

  factory AuditPage.fromJson(Map<String, dynamic> json) => AuditPage(
        items: ((json['items'] as List?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(AuditEntry.fromJson)
            .toList(),
        total: _toInt(json['total']),
        page: _toInt(json['page']),
        limit: _toInt(json['limit']),
        pages: _toInt(json['pages']),
      );
}

