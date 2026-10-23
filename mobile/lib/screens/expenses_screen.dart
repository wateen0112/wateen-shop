/// Expenses page — the counterpart of `pages/Expenses.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_scope.dart';
import '../widgets/common.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = <Expense>[];
  final TextEditingController _title = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _currency = 'SYP';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<Expense> list = await AppServices.instance.expenses.list();
      if (mounted) setState(() => _expenses = list);
    } catch (_) {
      if (mounted) setState(() => _expenses = <Expense>[]);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppServices.instance.expenses.create(
        title: _title.text.trim(),
        amount: double.tryParse(_amount.text.trim()) ?? 0,
        currency: _currency,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _title.clear();
        _amount.clear();
        _note.clear();
        _currency = 'SYP';
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذّر تسجيل المصروف';
      });
    }
  }

  Future<void> _delete(Expense e) async {
    try {
      await AppServices.instance.expenses.delete(e.id);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = AuthScope.of(context)?.can('expenses.edit') ?? false;

    return AppPage(
      children: <Widget>[
        if (canEdit)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SectionHead(title: 'تسجيل مصروف', subtitle: 'أضف مصروفاً جديداً'),
                if (_error != null) MsgBox(text: _error!),
                AppField(label: 'البيان', controller: _title, hint: 'مثال: إيجار المحل'),
                FormGrid(
                  children: <Widget>[
                    AppField(
                      label: 'المبلغ',
                      controller: _amount,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    AppDropdown(
                      label: 'العملة',
                      value: _currency,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'SYP', child: Text('ليرة سورية', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem<String>(value: 'USD', child: Text('دولار', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (String v) => setState(() => _currency = v),
                    ),
                  ],
                ),
                AppField(label: 'ملاحظة', controller: _note, hint: 'اختياري'),
                AppButton(
                  _saving ? 'جارٍ الحفظ…' : 'تسجيل المصروف',
                  busy: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: SectionHead(
            title: 'سجل المصروفات',
            trailing: CountBadge('${_expenses.length}'),
          ),
        ),
        if (_expenses.isEmpty)
          const AppCard(child: EmptyState('لا توجد مصروفات مسجّلة'))
        else
          ..._expenses.map((Expense e) => _item(e, canEdit)),
      ],
    );
  }

  Widget _item(Expense e, bool canEdit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x0D0F172A), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(e.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${fmtDate(e.date)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${fmtNum(e.amount)} ${e.currency}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          if (canEdit) ...<Widget>[
            const SizedBox(width: 6),
            Material(
              color: AppColors.softDanger,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _delete(e),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
