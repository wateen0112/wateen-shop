/// Sell page — the counterpart of `pages/Sell.jsx`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_scope.dart';
import '../widgets/barcode_scanner.dart';
import '../widgets/common.dart';
import '../widgets/customer_select.dart';

class _LoggedSale {
  _LoggedSale(this.sale, this.at);

  final Sale sale;
  final String at;
}

class SellScreen extends StatefulWidget {
  const SellScreen({super.key, this.rate});

  final double? rate;

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final FocusNode _queryFocus = FocusNode();

  List<_LoggedSale> _log = <_LoggedSale>[];
  String? _error;
  String? _success;
  bool _autoSell = true;
  bool _onCredit = false;
  String? _customerId;
  bool _busy = false;

  List<Product> _suggestions = <Product>[];
  bool _searching = false;
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    _quantity.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  bool get _canSearch =>
      AuthScope.of(context)?.can('products.view') ?? false;

  Future<void> _onQueryChanged() async {
    if (!mounted) return;
    final String term = _query.text.trim();
    if (term.isEmpty || !_canSearch) {
      setState(() {
        _suggestions = <Product>[];
        _searching = false;
      });
      return;
    }
    final int seq = ++_searchSeq;
    setState(() => _searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || seq != _searchSeq) return;
    try {
      final List<Product> list =
          await AppServices.instance.products.list(search: term);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = list.take(8).toList();
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = <Product>[];
        _searching = false;
      });
    }
  }

  int get _qty {
    final int v = int.tryParse(_quantity.text.trim()) ?? 1;
    return v < 1 ? 1 : v;
  }

  Future<void> _sell(String code) async {
    final String clean = code.trim();
    if (clean.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final Sale sale = await AppServices.instance.sales.create(
        barcode: clean,
        name: clean,
        quantity: _qty,
        onCredit: _onCredit,
        customerId: _onCredit ? _customerId : null,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _log = <_LoggedSale>[_LoggedSale(sale, fmtTime(DateTime.now())), ..._log];
        _success = _onCredit
            ? 'تم البيع على الحساب — أُضيف ${fmtNum(sale.totalSYP)} ل.س إلى دين الشخص'
            : 'تم البيع — الربح: ${fmtNum(sale.totalProfitSYP)} ل.س';
        _query.clear();
        _suggestions = <Product>[];
        _quantity.text = '1';
      });
      _queryFocus.requestFocus();
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
        _error = 'تعذّر إتمام البيع';
      });
    }
  }

  Future<void> _sellProduct(Product p) async {
    if (p.quantity < _qty) {
      setState(() => _error = 'الكمية غير كافية (المتاح: ${fmtNum(p.quantity)})');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final Sale sale = await AppServices.instance.sales.create(
        productId: p.id,
        quantity: _qty,
        onCredit: _onCredit,
        customerId: _onCredit ? _customerId : null,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _log = <_LoggedSale>[_LoggedSale(sale, fmtTime(DateTime.now())), ..._log];
        _success = _onCredit
            ? 'تم البيع على الحساب — أُضيف ${fmtNum(sale.totalSYP)} ل.س إلى دين الشخص'
            : 'تم البيع — الربح: ${fmtNum(sale.totalProfitSYP)} ل.س';
        _query.clear();
        _suggestions = <Product>[];
        _quantity.text = '1';
      });
      _queryFocus.requestFocus();
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
        _error = 'تعذّر إتمام البيع';
      });
    }
  }

  Future<void> _scan() async {
    final String? code = await openBarcodeScanner(context);
    if (code == null || !mounted) return;
    _query.text = code;
    if (_autoSell) {
      await _sell(code);
    } else {
      _queryFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canDebts = AuthScope.of(context)?.can('debts.view') ?? false;

    return AppPage(
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SectionHead(title: 'بيع سريع', subtitle: 'امسح الباركود أو ابحث باسم الصنف لتسجيل البيع'),
              if (widget.rate == null)
                const MsgBox(text: 'سعر الدولار غير مضبوط — الربح للمشتريات الدولارية غير دقيق.'),
              if (_error != null) MsgBox(text: _error!),
              if (_success != null) MsgBox(text: _success!, type: MsgType.success),
              const SizedBox(height: 4),
              _scanHero(),
              const SizedBox(height: 14),
              AppField(
                label: 'الباركود أو اسم الصنف',
                controller: _query,
                hint: 'امسح الباركود أو اكتب اسم الصنف',
                focusNode: _queryFocus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (String v) => _sell(v),
                suffix: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              if (_suggestions.isNotEmpty) ...<Widget>[
                _suggestionsList(),
                const SizedBox(height: 10),
              ],
              _stepper(),
              _switchRow('بيع تلقائي بعد المسح', _autoSell, (bool v) => setState(() => _autoSell = v)),
              if (canDebts)
                _switchRow('بيع على الحساب (دين لشخص)', _onCredit, (bool v) {
                  setState(() {
                    _onCredit = v;
                    if (!v) _customerId = null;
                  });
                }),
              if (_onCredit && canDebts) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'صاحب الدين',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                CustomerSelect(
                  value: _customerId,
                  onChange: (String? v) => setState(() => _customerId = v),
                  hint: 'اختر شخصاً أو أنشئ شخصاً جديداً — يُضاف مبلغ البيع إلى دينه',
                ),
              ],
              const SizedBox(height: 6),
              AppButton(
                'تأكيد البيع',
                busy: _busy,
                onPressed: () => _sell(_query.text),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionHead(
                title: 'مبيعات هذه الجلسة',
                trailing: CountBadge('${_log.length}'),
              ),
              if (_log.isEmpty)
                const EmptyState('لم تُسجّل أي عملية بيع بعد')
              else
                ..._log.map(_saleItem),
            ],
          ),
        ),
      ],
    );
  }

  Widget _suggestionsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: <Widget>[
          for (final Product p in _suggestions)
            InkWell(
              onTap: () => _sellProduct(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.barcode.isEmpty ? 'بدون باركود' : p.barcode} · ${p.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '${fmtNum(p.currentSalePrice)} ل.س',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.quantity > 0 ? 'متاح ${fmtNum(p.quantity)}' : 'غير متوفر',
                          style: TextStyle(
                            fontSize: 11,
                            color: p.quantity > 0 ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scanHero() {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: _scan,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'مسح باركود بالكاميرا',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'يُقرأ مباشرة بدون رفع صور',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepper() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'الكمية',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _stepButton('−', () {
                final int v = _qty - 1;
                _quantity.text = '${v < 1 ? 1 : v}';
              }),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '1'),
                ),
              ),
              const SizedBox(width: 8),
              _stepButton('+', () {
                _quantity.text = '${_qty + 1}';
                setState(() {});
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(String label, VoidCallback onTap) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _saleItem(_LoggedSale entry) {
    final Sale s = entry.sale;
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
                    '${fmtNum(s.salePrice)} ل.س',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.at} · كمية ${fmtNum(s.quantity)}${s.onCredit ? ' · على الحساب' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: s.onCredit ? AppColors.softWarn : AppColors.softSuccess,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                s.onCredit ? 'دين' : '+${fmtNum(s.totalProfitSYP)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: s.onCredit ? AppColors.warn : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
