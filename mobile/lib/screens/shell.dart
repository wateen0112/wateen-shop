/// App shell — app bar, permission-aware bottom tabs and the account sheet
/// (the counterpart of `App.jsx`).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../core/theme.dart';
import '../state/auth_controller.dart';
import '../widgets/account_sheet.dart';
import '../widgets/common.dart';
import 'barcodes_screen.dart';
import 'cashbox_screen.dart';
import 'debts_screen.dart';
import 'expenses_screen.dart';
import 'inventory_screen.dart';
import 'products_screen.dart';
import 'sell_screen.dart';
import 'users_screen.dart';

class TabSpec {
  const TabSpec(this.label, this.icon, this.perm);

  final String label;
  final IconData icon;
  final String perm;
}

const List<TabSpec> kTabs = <TabSpec>[
  TabSpec('الأصناف', Icons.inventory_2_outlined, 'products.view'),
  TabSpec('بيع', Icons.sell_outlined, 'sales.create'),
  TabSpec('الباركود', Icons.qr_code_2_rounded, 'barcodes.view'),
  TabSpec('المصروفات', Icons.account_balance_wallet_outlined, 'expenses.view'),
  TabSpec('الصندوق', Icons.savings_outlined, 'cashbox.view'),
  TabSpec('الديون', Icons.people_outline_rounded, 'debts.view'),
  TabSpec('الجرد', Icons.assignment_outlined, 'inventory.view'),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth});

  final AuthController auth;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;
  double? _rate;
  List<Permission> _catalog = const <Permission>[];
  Timer? _rateTimer;

  @override
  void initState() {
    super.initState();
    _loadRate();
    _loadCatalog();
    _rateTimer = Timer.periodic(const Duration(minutes: 5), (_) => _loadRate());
  }

  @override
  void dispose() {
    _rateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRate() async {
    try {
      final info = await AppServices.instance.rate.get();
      if (mounted) setState(() => _rate = info.rate);
    } catch (_) {
      if (mounted) setState(() => _rate = null);
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final list = await AppServices.instance.auth.permissions();
      if (mounted) setState(() => _catalog = list);
    } catch (_) {
      if (mounted) setState(() => _catalog = const <Permission>[]);
    }
  }

  /// Switches to the "الديون" tab (used by the cash-box page).
  void goToDebts() {
    final int target = kTabs.indexWhere((TabSpec t) => t.perm == 'debts.view');
    if (target >= 0) setState(() => _index = target);
  }

  void _openUsers() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => UsersScreen(auth: widget.auth)),
    );
  }

  List<TabSpec> get _visibleTabs =>
      kTabs.where((TabSpec t) => widget.auth.can(t.perm)).toList();

  Widget _pageFor(TabSpec tab) {
    switch (tab.perm) {
      case 'products.view':
        return ProductsScreen(rate: _rate);
      case 'sales.create':
        return SellScreen(rate: _rate);
      case 'barcodes.view':
        return const BarcodesScreen();
      case 'expenses.view':
        return const ExpensesScreen();
      case 'cashbox.view':
        return CashboxScreen(rate: _rate, onGoToDebts: goToDebts);
      case 'debts.view':
        return const DebtsScreen();
      case 'inventory.view':
        return const InventoryScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<TabSpec> tabs = _visibleTabs;
    final int index = tabs.isEmpty ? 0 : _index.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _AppBar(
              rate: _rate,
              onAccount: () => _openAccountSheet(context),
            ),
            Expanded(
              child: tabs.isEmpty
                  ? const _NoAccess()
                  : IndexedStack(
                      index: index,
                      children: <Widget>[
                        for (final TabSpec tab in tabs) _pageFor(tab),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: tabs.isEmpty
          ? null
          : _TabBar(
              tabs: tabs,
              index: index,
              onChanged: (int i) => setState(() => _index = i),
            ),
    );
  }

  void _openAccountSheet(BuildContext context) {
    if (widget.auth.user == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext ctx) => AccountSheet(
        user: widget.auth.user!,
        catalog: _catalog,
        onLogout: () => widget.auth.logout(),
        onManageUsers: _openUsers,
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppCard(
            child: Column(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لا تملك صلاحية الوصول',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اطلب من الأدمن تفعيل صلاحياتك من صفحة المستخدمين',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.rate, required this.onAccount});

  final double? rate;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.appBarGradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: <BoxShadow>[BoxShadow(color: AppColors.appBarShadow, blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_rounded, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'أبو وتين',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'إدارة المتجر',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                rate != null ? 'الدولار ${fmtNum(rate)} ل.س' : 'الدولار غير مضبوط',
                style: TextStyle(
                  color: rate != null ? Colors.white : Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.white.withValues(alpha: 0.18),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAccount,
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 19),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabs, required this.index, required this.onChanged});

  final List<TabSpec> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
        boxShadow: <BoxShadow>[BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          tabs[i].icon,
                          size: 21,
                          color: i == index ? AppColors.primary : AppColors.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                            color: i == index ? AppColors.primary : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
