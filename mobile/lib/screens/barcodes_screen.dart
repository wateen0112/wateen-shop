/// Barcode print sheet — the counterpart of `pages/Barcodes.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/barcode_utils.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_scope.dart';
import '../services/barcode_pdf.dart';
import '../widgets/common.dart';

class BarcodesScreen extends StatefulWidget {
  const BarcodesScreen({super.key});

  @override
  State<BarcodesScreen> createState() => _BarcodesScreenState();
}

class _BarcodesScreenState extends State<BarcodesScreen> {
  List<Product> _noBarcode = <Product>[];
  List<Product> _products = <Product>[];
  final Set<String> _selected = <String>{};
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final List<Product> missing = await AppServices.instance.products.noBarcode();
      final List<Product> all = await AppServices.instance.products.list();
      if (!mounted) return;
      setState(() {
        _noBarcode = missing;
        _products = all;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _noBarcode = <Product>[];
          _products = <Product>[];
        });
      }
    }
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _generateAll() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final List<BarcodeResult> res =
          await AppServices.instance.products.generateBarcodes(all: true);
      final int created = res.where((BarcodeResult r) => r.generated).length;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _selected.clear();
        _success = created > 0 ? 'تم توليد $created باركود صالح' : 'كل الأصناف لديها باركود صالح';
      });
      await _refresh();
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
        _error = 'تعذّر التوليد';
      });
    }
  }

  Future<void> _print(List<Product> list, {required bool generate}) async {
    final List<Product> chosen =
        list.where((Product p) => _selected.contains(p.id)).toList();
    if (chosen.isEmpty) return;
    List<BarcodeLabel> items = chosen
        .map((Product p) => BarcodeLabel(name: p.name, barcode: p.barcode))
        .toList();

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      if (generate) {
        final List<BarcodeResult> gen = await AppServices.instance.products.generateBarcodes(
          ids: chosen.map((Product p) => p.id).toList(),
        );
        if (gen.isNotEmpty) {
          items = gen.map((BarcodeResult g) => BarcodeLabel(name: g.name, barcode: g.barcode)).toList();
        }
      }
      await printBarcodeSheet(items);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _selected.clear();
        _success = 'تم تجهيز ملف الباركودات';
      });
      await _refresh();
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
        _error = 'تعذّر إنشاء ملف PDF';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = AuthScope.of(context)?.can('barcodes.manage') ?? false;
    final List<Product> printable =
        _products.where((Product p) => isValidBarcode(p.barcode)).toList();

    return AppPage(
      children: <Widget>[
        if (_error != null) MsgBox(text: _error!),
        if (_success != null) MsgBox(text: _success!, type: MsgType.success),
        _section(
          title: 'أصناف بدون باركود صالح',
          subtitle: 'تُولَّد لها باركودات EAN-13 داخلية صالحة للقراءة',
          list: _noBarcode,
          generate: true,
          bulk: true,
          canManage: canManage,
        ),
        _section(
          title: 'إعادة طباعة باركودات',
          subtitle: 'اختر الأصناف الموجودة لإعادة طباعتها',
          list: printable,
          generate: false,
          bulk: false,
          canManage: canManage,
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<Product> list,
    required bool generate,
    required bool bulk,
    required bool canManage,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHead(title: title, subtitle: subtitle, trailing: CountBadge('${list.length}')),
          if (list.isEmpty)
            const EmptyState('لا يوجد أصناف.')
          else
            ...list.map((Product p) => _item(p)),
          if (bulk && canManage) ...<Widget>[
            const SizedBox(height: 12),
            AppButton(
              _busy ? 'جارٍ التوليد…' : 'توليد تلقائي لكل الأصناف بلا باركود صالح',
              kind: AppButtonKind.secondary,
              icon: Icons.auto_awesome_rounded,
              busy: _busy,
              onPressed: _generateAll,
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            _busy ? 'جارٍ التوليد…' : 'توليد وطباعة PDF (${_selected.length})',
            icon: Icons.print_rounded,
            busy: _busy,
            onPressed: _selected.isEmpty || (generate && !canManage)
                ? null
                : () => _print(list, generate: generate),
          ),
        ],
      ),
    );
  }

  Widget _item(Product p) {
    final bool checked = _selected.contains(p.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: checked ? AppColors.primarySoft : AppColors.softGrey,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(
          color: checked ? AppColors.primary.withValues(alpha: 0.45) : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: () => _toggle(p.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => _toggle(p.id),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.barcode.isNotEmpty ? p.barcode : 'سيُولّد باركود جديد',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
