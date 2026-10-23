/// Customer picker with inline creation — the counterpart of `components/CustomerSelect.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

class CustomerSelect extends StatefulWidget {
  const CustomerSelect({super.key, required this.value, required this.onChange, this.hint, this.canEdit = true});

  final String? value;
  final ValueChanged<String?> onChange;
  final String? hint;
  final bool canEdit;

  @override
  State<CustomerSelect> createState() => _CustomerSelectState();
}

class _CustomerSelectState extends State<CustomerSelect> {
  List<Customer> _customers = <Customer>[];
  bool _creating = false;
  bool _busy = false;
  String? _error;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _initial = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
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
    });
    try {
      final Customer c = await AppServices.instance.customers.create(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        note: '',
        initialBalance: double.tryParse(_initial.text.trim()) ?? 0,
      );
      await _load();
      if (!mounted) return;
      setState(() {
        _creating = false;
        _busy = false;
      });
      widget.onChange(c.id);
      _name.clear();
      _phone.clear();
      _initial.clear();
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
        _error = 'تعذّر إنشاء الشخص';
      });
    }
  }

  Customer? get _selected {
    for (final Customer c in _customers) {
      if (c.id == widget.value) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_creating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppField(label: 'اسم الشخص', controller: _name, hint: 'مثال: أبو محمد'),
          FormGrid(
            children: <Widget>[
              AppField(label: 'الهاتف', controller: _phone, hint: 'اختياري', keyboardType: TextInputType.phone),
              AppField(
                label: 'رصيد مسبق للدين',
                controller: _initial,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          if (_error != null) MsgBox(text: _error!),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  'إلغاء',
                  kind: AppButtonKind.secondary,
                  block: true,
                  onPressed: () => setState(() => _creating = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  _busy ? 'جارٍ الحفظ…' : 'حفظ الشخص',
                  busy: _busy,
                  onPressed: _name.text.trim().isEmpty ? null : _create,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final Customer? selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>(widget.value),
          initialValue: widget.value,
          isExpanded: true,
          hint: const Text('بدون شخص (نقدي)', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(value: null, child: Text('بدون شخص (نقدي)')),
            ..._customers.map(
              (Customer c) => DropdownMenuItem<String?>(
                value: c.id,
                child: Text(
                  c.balance != 0 ? '${c.name} — عليه ${fmtNum(c.balance)}' : c.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: widget.onChange,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton(
            '＋ شخص جديد',
            kind: AppButtonKind.secondary,
            block: false,
            small: true,
            onPressed: widget.canEdit ? () => setState(() => _creating = true) : null,
          ),
        ),
        if (widget.hint != null) HintText(widget.hint!),
        if (selected != null && selected.balance > 0)
          HintText('عليه حالياً ${fmtNum(selected.balance)} ل.س', warn: true),
      ],
    );
  }
}
