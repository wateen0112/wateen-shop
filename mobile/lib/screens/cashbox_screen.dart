/// Cash box page — the counterpart of `pages/Profit.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_scope.dart';
import '../widgets/common.dart';

class CashboxScreen extends StatefulWidget {
  const CashboxScreen({super.key, this.rate, this.onGoToDebts});

  final double? rate;
  final VoidCallback? onGoToDebts;

  @override
  State<CashboxScreen> createState() => _CashboxScreenState();
}

class _CashboxScreenState extends State<CashboxScreen> {
  CashboxSummary? _box;
  final TextEditingController _initial = TextEditingController();
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
    _initial.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final CashboxSummary box = await AppServices.instance.cashbox.summary();
      if (!mounted) return;
      setState(() {
        _box = box;
        // The input keeps latin digits so it can be parsed back.
        _initial.text = box.initialBalance % 1 == 0
            ? box.initialBalance.toStringAsFixed(0)
            : box.initialBalance.toStringAsFixed(2);
      });
    } catch (_) {
      // The page simply keeps showing the dash placeholders.
    }
  }

  Future<void> _saveInitial() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final CashboxSummary box = await AppServices.instance.cashbox
          .setInitialBalance(double.tryParse(_initial.text.trim()) ?? 0);
      if (!mounted) return;
      setState(() {
        _box = box;
        _busy = false;
        _success = 'تم حفظ الرصيد الابتدائي';
      });
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

  @override
  Widget build(BuildContext context) {
    final bool canEdit = AuthScope.of(context)?.can('cashbox.edit') ?? false;
    final CashboxSummary? box = _box;
    final bool negative = box != null && box.current < 0;

    return AppPage(
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionHead(
                title: 'الصندوق',
                subtitle: 'رصيد ابتدائي + نقدية المبيعات − المصروفات',
              ),
              if (_error != null) MsgBox(text: _error!),
              if (_success != null) MsgBox(text: _success!, type: MsgType.success),
              KpiCard(
                label: 'رصيد الصندوق الحالي',
                value: box == null ? '—' : '${fmtNum(box.current)} ل.س',
                highlight: true,
                negative: negative,
                foot: box == null
                    ? null
                    : 'رصيد ابتدائي ${fmtNum(box.initialBalance)} + مبيعات ${fmtNum(box.salesCash)} − مصروفات ${fmtNum(box.expensesTotal)}',
                icon: Icons.account_balance_wallet_rounded,
              ),
              if (canEdit) ...<Widget>[
                const SizedBox(height: 4),
                AppField(
                  label: 'الرصيد الابتدائي للصندوق',
                  controller: _initial,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                AppButton(
                  _busy ? 'جارٍ الحفظ…' : 'حفظ الرصيد الابتدائي',
                  kind: AppButtonKind.secondary,
                  busy: _busy,
                  onPressed: _saveInitial,
                ),
                const HintText(
                  'المبلغ الموجود في الصندوق قبل بدء الحساب — يُضاف لكل المبيعات النقدية.',
                ),
              ],
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionHead(
                title: 'حركة الصندوق',
                subtitle: 'محسوبة بسعر الدولار الحالي',
              ),
              KpiCard(
                label: 'مبيعات نقدية',
                value: box == null ? '—' : '${fmtNum(box.salesCash)} ل.س',
                foot: box == null ? null : '${box.salesCount} عملية بيع',
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.success,
              ),
              KpiCard(
                label: 'المصروفات',
                value: box == null ? '—' : '${fmtNum(box.expensesTotal)} ل.س',
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.danger,
              ),
              KpiCard(
                label: 'مبيعات على الحساب (ديون)',
                value: box == null ? '—' : '${fmtNum(box.salesCredit)} ل.س',
                icon: Icons.swap_horiz_rounded,
              ),
              KpiCard(
                label: 'الربح الصافي',
                value: box == null ? '—' : '${fmtNum(box.netProfit)} ل.س',
                highlight: true,
                negative: box != null && box.netProfit < 0,
                icon: Icons.auto_graph_rounded,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionHead(
                title: 'الديون القائمة',
                subtitle: 'مستحق على الزبائن',
                trailing: CountBadge(box == null ? '—' : '${fmtNum(box.debtsTotal)} ل.س'),
              ),
              AppButton(
                'إدارة الديون',
                kind: AppButtonKind.secondary,
                icon: Icons.people_outline_rounded,
                onPressed: widget.onGoToDebts,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
