/// Audit log page — admin only view of who did what and when.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  AuditMeta _meta = const AuditMeta(actions: <AuditOption>[], entities: <AuditOption>[], users: <AuditUserOption>[]);
  List<AuditEntry> _items = <AuditEntry>[];
  int _total = 0;
  int _page = 1;
  int _pages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  String _action = '';
  String _entity = '';
  String _userId = '';
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      final AuditMeta meta = await AppServices.instance.audit.meta();
      if (mounted) setState(() => _meta = meta);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AuditPage result = await AppServices.instance.audit.list(
        page: 1,
        q: _search.text,
        action: _action,
        entity: _entity,
        userId: _userId,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = result.items;
        _total = result.total;
        _page = result.page;
        _pages = result.pages;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل سجل العمليات';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _pages) return;
    setState(() => _loadingMore = true);
    try {
      final AuditPage result = await AppServices.instance.audit.list(
        page: _page + 1,
        q: _search.text,
        action: _action,
        entity: _entity,
        userId: _userId,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _items = <AuditEntry>[..._items, ...result.items];
        _page = result.page;
        _pages = result.pages;
        _total = result.total;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _resetFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _action = '';
      _entity = '';
      _userId = '';
      _from = null;
      _to = null;
    });
    _load();
  }

  Future<void> _pickDate({required bool from}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (from ? _from : _to) ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      helpText: from ? 'من تاريخ' : 'إلى تاريخ',
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  bool get _hasFilters =>
      _search.text.trim().isNotEmpty ||
      _action.isNotEmpty ||
      _entity.isNotEmpty ||
      _userId.isNotEmpty ||
      _from != null ||
      _to != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text('سجل العمليات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: AppPage(
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SectionHead(title: 'فلترة السجل', subtitle: 'ابحث باسم المستخدم أو نص العملية أو حدّد النوع والمدة'),
                SearchField(
                  controller: _search,
                  hint: 'ابحث في العمليات…',
                  onChanged: _onSearchChanged,
                ),
                FormGrid(
                  children: <Widget>[
                    AppDropdown(
                      label: 'نوع العملية',
                      value: _action,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(value: '', child: Text('كل العمليات', style: TextStyle(fontSize: 13))),
                        ..._meta.actions.map(
                          (AuditOption a) => DropdownMenuItem<String>(
                            value: a.key,
                            child: Text('${a.label} (${fmtNum(a.count)})', style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                      onChanged: (String v) {
                        setState(() => _action = v);
                        _load();
                      },
                    ),
                    AppDropdown(
                      label: 'القسم',
                      value: _entity,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(value: '', child: Text('كل الأقسام', style: TextStyle(fontSize: 13))),
                        ..._meta.entities.map(
                          (AuditOption e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text('${e.label} (${fmtNum(e.count)})', style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                      onChanged: (String v) {
                        setState(() => _entity = v);
                        _load();
                      },
                    ),
                    AppDropdown(
                      label: 'المستخدم',
                      value: _userId,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(value: '', child: Text('كل المستخدمين', style: TextStyle(fontSize: 13))),
                        ..._meta.users.map(
                          (AuditUserOption u) => DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(
                              u.name.isNotEmpty ? '${u.name} (${u.username})' : u.username,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (String v) {
                        setState(() => _userId = v);
                        _load();
                      },
                    ),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        _from == null ? 'من تاريخ' : fmtDate(_from),
                        kind: AppButtonKind.secondary,
                        small: true,
                        icon: Icons.calendar_today_rounded,
                        onPressed: () => _pickDate(from: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        _to == null ? 'إلى تاريخ' : fmtDate(_to),
                        kind: AppButtonKind.secondary,
                        small: true,
                        icon: Icons.event_available_rounded,
                        onPressed: () => _pickDate(from: false),
                      ),
                    ),
                  ],
                ),
                if (_hasFilters) ...<Widget>[
                  const SizedBox(height: 8),
                  AppButton(
                    'مسح الفلاتر',
                    kind: AppButtonKind.secondary,
                    small: true,
                    icon: Icons.filter_alt_off_rounded,
                    onPressed: _resetFilters,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: SectionHead(
              title: 'العمليات',
              subtitle: 'الأحدث أولاً',
              trailing: CountBadge(fmtNum(_total)),
            ),
          ),
          if (_error != null) MsgBox(text: _error!),
          if (_loading && _items.isEmpty)
            const AppCard(child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ))
          else if (_items.isEmpty)
            const AppCard(child: EmptyState('لا توجد عمليات مطابقة'))
          else
            ..._items.map(_entryCard),
          if (_items.isNotEmpty && _page < _pages)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppButton(
                'عرض المزيد',
                kind: AppButtonKind.secondary,
                busy: _loadingMore,
                onPressed: _loadMore,
              ),
            ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: HintText('تم عرض ${fmtNum(_items.length)} من ${fmtNum(_total)} عملية'),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String entity) {
    switch (entity) {
      case 'product':
        return Icons.inventory_2_rounded;
      case 'sale':
        return Icons.point_of_sale_rounded;
      case 'expense':
        return Icons.receipt_long_rounded;
      case 'inventory':
        return Icons.fact_check_rounded;
      case 'customer':
      case 'debt':
        return Icons.people_alt_rounded;
      case 'cashbox':
        return Icons.account_balance_wallet_rounded;
      case 'user':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.login_rounded;
    }
  }

  PillKind _kindFor(String action) {
    if (action == 'login.failed') return PillKind.danger;
    if (action.endsWith('.delete')) return PillKind.danger;
    if (action.endsWith('.create') || action.endsWith('.price_add') || action.endsWith('.barcode_generate')) {
      return PillKind.ok;
    }
    if (action == 'login' || action == 'logout') return PillKind.normal;
    return PillKind.warn;
  }

  Widget _entryCard(AuditEntry entry) {
    final DateTime? at = entry.createdAt;
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => _showDetails(entry),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: Icon(_iconFor(entry.entity), size: 19, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.summary,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.45),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${entry.actorLabel}${entry.username.isNotEmpty && entry.actorLabel != entry.username ? ' (${entry.username})' : ''} • ${entry.role == 'admin' ? 'أدمن' : 'مستخدم'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      at == null ? '—' : fmtTime(at),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      at == null ? '' : fmtDate(at),
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                Pill(entry.actionLabel, kind: _kindFor(entry.action)),
                Pill(entry.entityLabel),
                if (entry.label.isNotEmpty && entry.label != entry.username) Pill(entry.label),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(AuditEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.actionLabel,
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: <Widget>[
                    _detailRow('الوصف', entry.summary),
                    _detailRow('المستخدم', '${entry.actorLabel} (${entry.username})'),
                    _detailRow('الدور', entry.role == 'admin' ? 'أدمن' : 'مستخدم'),
                    _detailRow('القسم', entry.entityLabel),
                    if (entry.label.isNotEmpty) _detailRow('العنصر', entry.label),
                    if (entry.entityId.isNotEmpty) _detailRow('المعرّف', entry.entityId),
                    if (entry.createdAt != null) _detailRow('الوقت', fmtDateTime(entry.createdAt)),
                    if (entry.ip.isNotEmpty) _detailRow('عنوان IP', entry.ip),
                    if (entry.details != null && entry.details!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      const Text('التفاصيل', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.softGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ').convert(entry.details),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
