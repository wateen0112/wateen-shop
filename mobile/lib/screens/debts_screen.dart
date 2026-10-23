/// Debts page — the counterpart of `pages/Debts.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_scope.dart';
import '../widgets/common.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  List<Customer> _customers = <Customer>[];
  final TextEditingController _search = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _initial = TextEditingController();

  bool _showForm = false;
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<Customer> list = await AppServices.instance.customers.list();
      if (mounted) setState(() => _customers = list);
    } catch (_) {
      if (mounted) setState(() => _customers = <Customer>[]);
    }
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await AppServices.instance.customers.create(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        note: _note.text.trim(),
        initialBalance: double.tryParse(_initial.text.trim()) ?? 0,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _showForm = false;
        _name.clear();
        _phone.clear();
        _note.clear();
        _initial.clear();
        _success = 'تمت إضافة الشخص';
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّرت الإضافة';
      });
    }
  }

  List<Customer> get _filtered {
    final String q = _search.text.trim();
    if (q.isEmpty) return _customers;
    return _customers
        .where((Customer c) => c.name.contains(q) || c.phone.contains(q))
        .toList();
  }

  Future<void> _open(Customer c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => CustomerSheet(
        customerId: c.id,
        onChanged: _load,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = AuthScope.of(context)?.can('debts.edit') ?? false;
    final double total = _customers.fold<double>(0, (double s, Customer c) => s + c.balance);
    final List<Customer> filtered = _filtered;

    return AppPage(
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionHead(title: 'الديون', subtitle: 'أشخاص عليهم ديون للمتجر'),
              if (_error != null) MsgBox(text: _error!),
              if (_success != null) MsgBox(text: _success!, type: MsgType.success),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: total > 0 ? AppColors.softDanger : AppColors.softGrey,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('إجمالي الديون القائمة', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtNum(total)} ل.س',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: total > 0 ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                AppButton(
                  _showForm ? 'إخفاء' : '＋ شخص جديد',
                  kind: _showForm ? AppButtonKind.secondary : AppButtonKind.primary,
                  onPressed: () => setState(() => _showForm = !_showForm),
                ),
              if (_showForm) ...<Widget>[
                const SizedBox(height: 12),
                AppField(label: 'اسم الشخص', controller: _name, hint: 'مثال: أبو محمد'),
                FormGrid(
                  children: <Widget>[
                    AppField(
                      label: 'الهاتف',
                      controller: _phone,
                      hint: 'اختياري',
                      keyboardType: TextInputType.phone,
                    ),
                    AppField(
                      label: 'رصيد مسبق للدين',
                      controller: _initial,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
                AppField(label: 'ملاحظة', controller: _note, hint: 'اختياري'),
                AppButton(
                  _busy ? 'جارٍ الحفظ…' : 'حفظ الشخص',
                  busy: _busy,
                  onPressed: _create,
                ),
              ],
            ],
          ),
        ),
        SearchField(
          controller: _search,
          hint: 'ابحث بالاسم أو الهاتف',
          onChanged: (_) => setState(() {}),
        ),
        if (filtered.isEmpty)
          const AppCard(child: EmptyState('لا يوجد أشخاص.'))
        else
          ...filtered.map(_item),
      ],
    );
  }

  Widget _item(Customer c) {
    final bool owes = c.balance > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => _open(c),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(c.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${c.phone.isEmpty ? 'بدون هاتف' : c.phone}${owes ? ' • عليه ${fmtNum(c.balance)} ل.س' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: owes ? AppColors.softDanger : AppColors.softSuccess,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                owes ? fmtNum(c.balance) : 'مسدَّد',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: owes ? AppColors.danger : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The per-person statement sheet.
class CustomerSheet extends StatefulWidget {
  const CustomerSheet({super.key, required this.customerId, this.onChanged});

  final String customerId;
  final VoidCallback? onChanged;

  @override
  State<CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<CustomerSheet> {
  Customer? _detail;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _type = 'debit';
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final Customer c = await AppServices.instance.customers.get(widget.customerId);
      if (mounted) setState(() => _detail = c);
    } catch (_) {
      if (mounted) {
        setState(() => _detail = const Customer(
              id: '',
              name: '…',
              phone: '',
              note: '',
              initialBalance: 0,
              balance: 0,
            ));
      }
    }
  }

  Future<void> _saveMove() async {
    final double amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await AppServices.instance.customers.addDebt(
        widget.customerId,
        type: _type,
        amount: amount,
        note: _note.text.trim(),
      );
      final Customer fresh = await AppServices.instance.customers.get(widget.customerId);
      if (!mounted) return;
      setState(() {
        _detail = fresh;
        _busy = false;
        _amount.clear();
        _note.clear();
        _success = _type == 'debit' ? 'تمت إضافة الدين' : 'تم تسجيل التسديد';
      });
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر الحفظ';
      });
    }
  }

  Future<void> _removeMove(DebtMovement m) async {
    try {
      await AppServices.instance.customers.deleteDebt(widget.customerId, m.id);
      final Customer fresh = await AppServices.instance.customers.get(widget.customerId);
      if (!mounted) return;
      setState(() => _detail = fresh);
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _removePerson() async {
    final bool ok = await confirmDialog(context, 'حذف هذا الشخص وكل حركات دينه؟');
    if (!ok) return;
    try {
      await AppServices.instance.customers.delete(widget.customerId);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = AuthScope.of(context)?.can('debts.edit') ?? false;
    final Customer? d = _detail;
    final bool owes = (d?.balance ?? 0) > 0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext ctx, ScrollController scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          d?.name ?? '…',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          (d?.phone.isEmpty ?? true) ? 'بدون هاتف' : d!.phone,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    color: AppColors.ink,
                    background: AppColors.softGrey,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: owes ? AppColors.softDanger : AppColors.softSuccess,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('الرصيد الحالي', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(
                          '${fmtNum(d?.balance)} ل.س',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: owes ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((d?.initialBalance ?? 0) > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    HintText('يشمل رصيداً مسبقاً قدره ${fmtNum(d!.initialBalance)} ل.س'),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 10),
                    MsgBox(text: _error!),
                  ],
                  if (_success != null) ...<Widget>[
                    const SizedBox(height: 10),
                    MsgBox(text: _success!, type: MsgType.success),
                  ],
                  if (canEdit) ...<Widget>[
                    const SizedBox(height: 14),
                    _segmented(),
                    const SizedBox(height: 12),
                    FormGrid(
                      children: <Widget>[
                        AppField(
                          label: 'المبلغ',
                          controller: _amount,
                          hint: '0',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        AppField(label: 'ملاحظة', controller: _note, hint: 'اختياري'),
                      ],
                    ),
                    AppButton(
                      _type == 'debit' ? 'إضافة إلى الدين' : 'تسجيل التسديد',
                      busy: _busy,
                      onPressed: _saveMove,
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text('كشف الحساب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (d == null || d.movements.isEmpty)
                    const EmptyState('لا توجد حركات.')
                  else
                    ...d.movements.map((DebtMovement m) => _movement(m, canEdit)),
                  if (canEdit) ...<Widget>[
                    const SizedBox(height: 14),
                    AppButton(
                      'حذف الشخص',
                      kind: AppButtonKind.danger,
                      icon: Icons.delete_outline_rounded,
                      onPressed: _removePerson,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented() {
    Widget tab(String label, String value) {
      final bool active = _type == value;
      return Expanded(
        child: Material(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _type = value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? (value == 'debit' ? AppColors.danger : AppColors.success)
                        : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: <Widget>[tab('دين جديد', 'debit'), tab('تسديد', 'credit')]),
    );
  }

  Widget _movement(DebtMovement m, bool canEdit) {
    final bool debit = m.isDebit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.softGrey,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${debit ? 'دين' : 'تسديد'} • ${fmtNum(m.amount)} ل.س',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDate(m.date)}${m.note.isNotEmpty ? ' • ${m.note}' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              '${debit ? '+' : '−'}${fmtNum(m.amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: debit ? AppColors.danger : AppColors.success,
              ),
            ),
            if (canEdit) ...<Widget>[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _removeMove(m),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
