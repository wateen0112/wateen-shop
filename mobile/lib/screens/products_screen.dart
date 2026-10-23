/// Products page — the counterpart of `pages/Products.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/barcode_utils.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../state/auth_scope.dart';
import '../widgets/barcode_preview.dart';
import '../widgets/barcode_scanner.dart';
import '../widgets/common.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.rate});

  /// USD → SYP rate (used to show the purchase price in SYP).
  final double? rate;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _barcode = TextEditingController();
  final TextEditingController _unit = TextEditingController(text: 'قطعة');
  final TextEditingController _quantity = TextEditingController(text: '0');
  final TextEditingController _purchasePrice = TextEditingController();
  final TextEditingController _salePrice = TextEditingController();
  String _purchaseCurrency = 'SYP';

  final TextEditingController _search = TextEditingController();
  final Map<String, TextEditingController> _qtyControllers = <String, TextEditingController>{};
  final Map<String, TextEditingController> _priceControllers = <String, TextEditingController>{};

  List<Product> _products = <Product>[];
  bool _busy = false;
  String? _error;
  String? _success;
  String? _generatedName;
  String? _generatedBarcode;

  @override
  void initState() {
    super.initState();
    _load();
    _barcode.addListener(_onBarcodeChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _unit.dispose();
    _quantity.dispose();
    _purchasePrice.dispose();
    _salePrice.dispose();
    _search.dispose();
    for (final TextEditingController c in _qtyControllers.values) {
      c.dispose();
    }
    for (final TextEditingController c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onBarcodeChanged() {
    setState(() {});
  }

  Future<void> _load() async {
    try {
      final List<Product> list = await AppServices.instance.products.list(search: _search.text.trim());
      if (!mounted) return;
      setState(() {
        _products = list;
        for (final Product p in list) {
          _qtyControllers.putIfAbsent(p.id, TextEditingController.new);
          _priceControllers.putIfAbsent(p.id, TextEditingController.new);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _products = <Product>[]);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final String productName = _name.text.trim();
      final Product created = await AppServices.instance.products.create(
        name: productName,
        barcode: _barcode.text.trim(),
        unit: _unit.text.trim(),
        quantity: double.tryParse(_quantity.text.trim()) ?? 0,
        purchasePrice: double.tryParse(_purchasePrice.text.trim()) ?? 0,
        purchaseCurrency: _purchaseCurrency,
        salePrice: double.tryParse(_salePrice.text.trim()),
      );
      final bool generated = !isValidBarcode(_barcode.text.trim()) || _barcode.text.trim().isEmpty;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _name.clear();
        _barcode.clear();
        _quantity.text = '0';
        _purchasePrice.clear();
        _salePrice.clear();
        _generatedName = generated ? productName : null;
        _generatedBarcode = generated ? created.barcode : null;
        _success = generated ? 'تمت إضافة الصنف مع باركود مُولّد تلقائياً' : 'تمت إضافة الصنف';
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

  Future<void> _fixBarcode(Product p) async {
    try {
      final List<BarcodeResult> res =
          await AppServices.instance.products.generateBarcodes(ids: <String>[p.id]);
      if (!mounted) return;
      setState(() {
        _success = 'تم توليد باركود ${res.isEmpty ? '' : res.first.barcode} للصنف ${p.name}';
        _error = null;
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر توليد الباركود');
    }
  }

  Future<void> _changeQty(Product p) async {
    final String raw = _qtyControllers[p.id]?.text.trim() ?? '';
    try {
      await AppServices.instance.products.update(
        p.id,
        name: p.name,
        barcode: p.barcode,
        unit: p.unit,
        quantity: double.tryParse(raw) ?? p.quantity,
        purchasePrice: p.purchasePrice,
        purchaseCurrency: p.purchaseCurrency,
      );
      _qtyControllers[p.id]?.clear();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _newSalePrice(Product p) async {
    final String raw = _priceControllers[p.id]?.text.trim() ?? '';
    if (raw.isEmpty) return;
    try {
      await AppServices.instance.products.addSalePrice(p.id, double.tryParse(raw) ?? 0, '');
      _priceControllers[p.id]?.clear();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _delete(Product p) async {
    try {
      await AppServices.instance.products.delete(p.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _scan({required bool intoForm}) async {
    final String? code = await openBarcodeScanner(context);
    if (code == null || !mounted) return;
    if (intoForm) {
      _barcode.text = code;
    } else {
      _search.text = code;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController? auth = AuthScope.of(context);
    final bool canEdit = auth?.can('products.edit') ?? false;
    final bool canBarcodes = auth?.can('barcodes.manage') ?? false;
    final bool barcodeValid = isValidBarcode(_barcode.text.trim());

    return AppPage(
      children: <Widget>[
        if (canEdit) ...<Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SectionHead(title: 'صنف جديد', subtitle: 'أضف البيانات وامسح الباركود'),
                if (_error != null) MsgBox(text: _error!),
                if (_success != null) MsgBox(text: _success!, type: MsgType.success),
                if (_generatedBarcode != null) _generatedCard(),
                AppField(label: 'اسم الصنف', controller: _name, hint: 'مثال: شاي العروسة'),
                AppField(
                  label: 'الباركود',
                  controller: _barcode,
                  hint: 'امسح بالكاميرا أو اكتب الرقم',
                  suffix: IconButton(
                    onPressed: () => _scan(intoForm: true),
                    icon: const Icon(Icons.photo_camera_rounded, color: AppColors.primary, size: 20),
                    tooltip: 'مسح الباركود بالكاميرا',
                  ),
                ),
                HintText(
                  _barcode.text.trim().isNotEmpty && !barcodeValid
                      ? 'هذا الرقم ليس باركوداً صالحاً — سيُستبدل بباركود تلقائي عند الحفظ'
                      : 'اتركه فارغاً وسيُولّد باركود EAN-13 صالح تلقائياً',
                  warn: _barcode.text.trim().isNotEmpty && !barcodeValid,
                ),
                BarcodePreview(value: _barcode.text),
                FormGrid(
                  children: <Widget>[
                    AppField(label: 'الوحدة', controller: _unit, hint: 'قطعة'),
                    AppField(
                      label: 'الكمية',
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    AppField(
                      label: 'سعر الشراء',
                      controller: _purchasePrice,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    AppDropdown(
                      label: 'عملة الشراء',
                      value: _purchaseCurrency,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'SYP', child: Text('ليرة سورية', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem<String>(value: 'USD', child: Text('دولار', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (String v) => setState(() => _purchaseCurrency = v),
                    ),
                  ],
                ),
                AppField(
                  label: 'سعر البيع (ل.س)',
                  controller: _salePrice,
                  hint: 'اتركه فارغاً إن لم تحدده بعد',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                AppButton('إضافة الصنف', busy: _busy, onPressed: _submit),
              ],
            ),
          ),
        ],
        SectionHead(
          title: 'الأصناف',
          trailing: CountBadge('${_products.length}'),
        ),
        SearchField(
          controller: _search,
          hint: 'ابحث بالاسم أو الباركود',
          onChanged: (_) => _load(),
          onScan: () => _scan(intoForm: false),
        ),
        if (_products.isEmpty)
          const AppCard(child: EmptyState('لا توجد أصناف مطابقة'))
        else
          ..._products.map(
            (Product p) => _productCard(p, canEdit, canBarcodes),
          ),
      ],
    );
  }

  Widget _generatedCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softSuccess,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.auto_awesome_rounded, size: 17, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'تم توليد باركود تلقائي',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _generatedName = null;
                  _generatedBarcode = null;
                }),
                child: const Icon(Icons.close_rounded, size: 18, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BarcodePreview(value: _generatedBarcode ?? '', height: 54),
          Text(
            'الصنف: ${_generatedName ?? ''} — يمكنك طباعته من صفحة «الباركود»',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Product p, bool canEdit, bool canBarcodes) {
    final bool valid = isValidBarcode(p.barcode);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(p.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (valid)
                          Text(
                            p.barcode,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              letterSpacing: 1,
                            ),
                          )
                        else
                          Pill(p.barcode.isEmpty ? 'بدون باركود' : 'باركود غير صالح', kind: PillKind.warn),
                        Pill(p.unit),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      fmtNum(p.quantity),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                    const Text('متوفر', style: TextStyle(fontSize: 10.5, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.softGrey,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Column(
              children: <Widget>[
                _priceRow('سعر الشراء', '${fmtNum(p.purchasePrice)} ${p.purchaseCurrency}'),
                const SizedBox(height: 6),
                _priceRow(
                  'سعر البيع',
                  p.currentSalePrice != null ? '${fmtNum(p.currentSalePrice)} ل.س' : '—',
                ),
                if (p.purchaseCurrency == 'USD' && widget.rate != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _priceRow('الشراء بالليرة', '${fmtNum(p.purchasePrice * widget.rate!)} ل.س'),
                ],
              ],
            ),
          ),
          if (canEdit) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _qtyControllers[p.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: 'الكمية'),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton('حفظ', kind: AppButtonKind.secondary, small: true, block: false, onPressed: () => _changeQty(p)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _priceControllers[p.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(hintText: 'سعر بيع جديد'),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton('إضافة', kind: AppButtonKind.secondary, small: true, block: false, onPressed: () => _newSalePrice(p)),
              ],
            ),
          ],
          if (!valid && canBarcodes) ...<Widget>[
            const SizedBox(height: 10),
            AppButton(
              'توليد باركود لهذا الصنف',
              kind: AppButtonKind.secondary,
              small: true,
              icon: Icons.auto_awesome_rounded,
              onPressed: () => _fixBarcode(p),
            ),
          ],
          if (canEdit) ...<Widget>[
            const SizedBox(height: 10),
            AppButton(
              'حذف الصنف',
              kind: AppButtonKind.danger,
              small: true,
              icon: Icons.delete_outline_rounded,
              onPressed: () => _delete(p),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
