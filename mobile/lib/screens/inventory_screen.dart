/// Inventory page — the counterpart of `pages/Inventory.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_scope.dart';
import '../widgets/common.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _sheet = <Product>[];
  List<InventorySnapshot> _history = <InventorySnapshot>[];
  final Map<String, TextEditingController> _actual = <String, TextEditingController>{};
  bool _showHistory = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHistory();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _actual.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<Product> list = await AppServices.instance.inventory.sheet();
      if (!mounted) return;
      setState(() {
        _sheet = list;
        for (final Product p in list) {
          _actual.putIfAbsent(p.id, TextEditingController.new);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _sheet = <Product>[]);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final List<InventorySnapshot> list = await AppServices.instance.inventory.snapshots();
      if (mounted) setState(() => _history = list);
    } catch (_) {
      if (mounted) setState(() => _history = <InventorySnapshot>[]);
    }
  }

  List<Product> get _filled => _sheet.where((Product p) {
        final String v = _actual[p.id]?.text.trim() ?? '';
        return v.isNotEmpty;
      }).toList();

  Future<void> _submit() async {
    final List<Product> filled = _filled;
    if (filled.isEmpty) {
      setState(() => _error = 'أدخل الكميات الفعلية أولاً');
      return;
    }
    final bool ok = await confirmDialog(
      context,
      'سيتم تعديل كميات ${filled.length} صنفاً إلى العدّ الفعلي. متابعة؟',
    );
    if (!ok) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppServices.instance.inventory.save(
        items: filled
            .map((Product p) => (
                  productId: p.id,
                  actualQty: double.tryParse(_actual[p.id]?.text.trim() ?? '') ?? 0,
                ))
            .toList(),
      );
      for (final TextEditingController c in _actual.values) {
        c.clear();
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = null;
      });
      await _load();
      await _loadHistory();
      if (!mounted) return;
      showToast(context, 'تم حفظ الجرد');
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
        _error = 'تعذّر حفظ الجرد';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = AuthScope.of(context)?.can('inventory.edit') ?? false;
    final int filledCount = _filled.length;

    return AppPage(
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionHead(
                title: 'جرد جديد',
                subtitle: 'أدخل الكمية الفعلية لكل صنف',
                trailing: CountBadge('$filledCount/${_sheet.length}'),
              ),
              if (_error != null) MsgBox(text: _error!),
              if (_sheet.isEmpty)
                const EmptyState('لا توجد أصناف للجرد')
              else
                ..._sheet.map((Product p) => _row(p, canEdit)),
              if (canEdit) ...<Widget>[
                const SizedBox(height: 14),
                AppButton(
                  _saving ? 'جارٍ الحفظ…' : 'حفظ الجرد وتحديث الكميات',
                  busy: _saving,
                  onPressed: filledCount == 0 ? null : _submit,
                ),
              ],
              const SizedBox(height: 8),
              AppButton(
                '${_showHistory ? 'إخفاء' : 'عرض'} سجل الجردات السابقة',
                kind: AppButtonKind.secondary,
                onPressed: () => setState(() => _showHistory = !_showHistory),
              ),
            ],
          ),
        ),
        if (_showHistory) ..._history.map(_historyCard),
      ],
    );
  }

  Widget _row(Product p, bool canEdit) {
    final TextEditingController controller = _actual[p.id] ?? TextEditingController();
    final String raw = controller.text.trim();
    final double? diff = raw.isEmpty ? null : (double.tryParse(raw) ?? 0) - p.quantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                  Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    'مسجّلة: ${fmtNum(p.quantity)} ${p.unit}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 86,
              child: TextField(
                controller: controller,
                enabled: canEdit,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: numericFormatters(),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: '—', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              child: diff == null
                  ? const SizedBox.shrink()
                  : Text(
                      '${diff > 0 ? '+' : ''}${fmtNum(diff)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: diff == 0 ? AppColors.success : AppColors.danger,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(InventorySnapshot inv) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHead(
            title: fmtDate(inv.date),
            subtitle: fmtTime(inv.date),
            trailing: CountBadge('${inv.items.length}'),
          ),
          ...inv.items.map((InventoryItem it) {
            final double d = it.actualQty - it.recordedQty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(it.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                        Text(
                          'مسجّلة ${fmtNum(it.recordedQty)} · فعلية ${fmtNum(it.actualQty)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${d > 0 ? '+' : ''}${fmtNum(d)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: d == 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
