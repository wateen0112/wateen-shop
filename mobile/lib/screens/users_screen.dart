/// Users page — the counterpart of `pages/Users.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/permissions.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/permission_matrix.dart';
import 'audit_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = <AppUser>[];
  List<Permission> _catalog = <Permission>[];

  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String _role = 'user';
  List<String> _permissions = List<String>.of(kDefaultUserPermissions);

  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCatalog();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<AppUser> list = await AppServices.instance.users.list();
      if (mounted) setState(() => _users = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المستخدمين');
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final List<Permission> list = await AppServices.instance.auth.permissions();
      if (mounted) setState(() => _catalog = list);
    } catch (_) {
      if (mounted) setState(() => _catalog = kPermissions);
    }
  }

  Map<String, List<Permission>> get _groups => groupPermissions(_catalog.isEmpty ? kPermissions : _catalog);

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await AppServices.instance.users.create(
        username: _username.text.trim(),
        name: _name.text.trim(),
        password: _password.text,
        role: _role,
        permissions: _role == 'admin' ? const <String>[] : _permissions,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = 'تم إنشاء المستخدم ${_username.text.trim()}';
        _username.clear();
        _password.clear();
        _name.clear();
        _role = 'user';
        _permissions = List<String>.of(kDefaultUserPermissions);
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
        _error = 'تعذّر إنشاء المستخدم';
      });
    }
  }

  Future<void> _delete(AppUser u) async {
    final bool ok = await confirmDialog(context, 'حذف المستخدم ${u.username}؟');
    if (!ok) return;
    try {
      await AppServices.instance.users.delete(u.id);
      if (!mounted) return;
      setState(() => _success = 'تم حذف المستخدم');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _edit(AppUser u) async {
    final bool? changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _EditUserSheet(
        user: u,
        groups: _groups,
        defaultPermissions: List<String>.of(kDefaultUserPermissions),
      ),
    );
    if (changed == true) {
      await _load();
      if (u.id == widget.auth.user?.id) {
        await widget.auth.boot();
      }
      if (mounted) setState(() => _success = 'تم حفظ التعديلات');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text('المستخدمون', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AuditScreen()),
            ),
            icon: const Icon(Icons.history_rounded),
            tooltip: 'سجل العمليات',
          ),
        ],
      ),
      body: AppPage(
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SectionHead(title: 'مستخدم جديد', subtitle: 'أنشئ حساباً وحدّد صلاحياته'),
                if (_success != null) MsgBox(text: _success!, type: MsgType.success),
                if (_error != null) MsgBox(text: _error!),
                FormGrid(
                  children: <Widget>[
                    AppField(label: 'اسم المستخدم', controller: _username, hint: 'sara'),
                    AppField(label: 'كلمة المرور', controller: _password, hint: '4 أحرف على الأقل'),
                    AppField(label: 'الاسم الكامل', controller: _name, hint: 'سارة أحمد'),
                    AppDropdown(
                      label: 'الدور',
                      value: _role,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'user', child: Text('مستخدم', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem<String>(value: 'admin', child: Text('أدمن', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (String v) => setState(() {
                        final String previous = _role;
                        _role = v;
                        if (v == 'admin') {
                          _permissions = <String>[];
                        } else if (previous == 'admin') {
                          _permissions = List<String>.of(kDefaultUserPermissions);
                        }
                      }),
                    ),
                  ],
                ),
                if (_role == 'user')
                  PermissionMatrix(
                    groups: _groups,
                    selected: _permissions,
                    onToggle: (String key) => setState(() {
                      if (!_permissions.remove(key)) _permissions.add(key);
                    }),
                  ),
                const SizedBox(height: 8),
                AppButton(
                  'إضافة المستخدم',
                  busy: _busy,
                  onPressed: _create,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: SectionHead(
              title: 'المستخدمون',
              trailing: CountBadge('${_users.length}'),
            ),
          ),
          if (_users.isEmpty)
            const AppCard(child: EmptyState('لا يوجد مستخدمون'))
          else
            ..._users.map(_userCard),
        ],
      ),
    );
  }

  Widget _userCard(AppUser u) {
    final bool isMe = u.id == widget.auth.user?.id;

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
                    Text(
                      u.name.isNotEmpty ? u.name : u.username,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: u.active ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        Pill(u.username),
                        Pill(u.role == 'admin' ? 'أدمن' : 'مستخدم', kind: u.role == 'admin' ? PillKind.ok : PillKind.normal),
                        Pill(u.role == 'admin' ? 'كل الصلاحيات' : '${u.permissions.length} صلاحية'),
                        if (!u.active) const Pill('معطّل', kind: PillKind.warn),
                      ],
                    ),
                  ],
                ),
              ),
              AppButton(
                'تعديل',
                kind: AppButtonKind.secondary,
                small: true,
                block: false,
                onPressed: () => _edit(u),
              ),
            ],
          ),
          if (!isMe) ...<Widget>[
            const SizedBox(height: 10),
            AppButton(
              'حذف المستخدم',
              kind: AppButtonKind.danger,
              small: true,
              icon: Icons.delete_outline_rounded,
              onPressed: () => _delete(u),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditUserSheet extends StatefulWidget {
  const _EditUserSheet({
    required this.user,
    required this.groups,
    required this.defaultPermissions,
  });

  final AppUser user;
  final Map<String, List<Permission>> groups;
  final List<String> defaultPermissions;

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.user.name);
  final TextEditingController _password = TextEditingController();
  late String _role = widget.user.role;
  late bool _active = widget.user.active;
  late List<String> _permissions = List<String>.of(widget.user.permissions);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.users.update(
        id: widget.user.id,
        name: _name.text.trim(),
        role: _role,
        permissions: _role == 'admin' ? const <String>[] : _permissions,
        active: _active,
        password: _password.text.isEmpty ? null : _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
        _error = 'تعذّر حفظ التعديلات';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
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
                      'تعديل ${widget.user.name.isNotEmpty ? widget.user.name : widget.user.username}',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    color: AppColors.ink,
                    background: AppColors.softGrey,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: <Widget>[
                  if (_error != null) MsgBox(text: _error!),
                  AppField(label: 'الاسم الكامل', controller: _name),
                  AppDropdown(
                    label: 'الدور',
                    value: _role,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'user', child: Text('مستخدم', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem<String>(value: 'admin', child: Text('أدمن', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (String v) => setState(() {
                      final String previous = _role;
                      _role = v;
                      if (v == 'admin') {
                        _permissions = <String>[];
                      } else if (previous == 'admin') {
                        _permissions = List<String>.of(widget.defaultPermissions);
                      }
                    }),
                  ),
                  _activeRow(),
                  AppField(
                    label: 'كلمة مرور جديدة (اختياري)',
                    controller: _password,
                    hint: 'اتركها فارغة للإبقاء عليها',
                  ),
                  if (_role == 'user')
                    PermissionMatrix(
                      groups: widget.groups,
                      selected: _permissions,
                      onToggle: (String key) => setState(() {
                        if (!_permissions.remove(key)) _permissions.add(key);
                      }),
                    ),
                  const SizedBox(height: 8),
                  AppButton(
                    'حفظ التعديلات',
                    busy: _busy,
                    icon: Icons.check_rounded,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Checkbox(
            value: _active,
            onChanged: (bool? v) => setState(() => _active = v ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          const Text('الحساب مفعّل', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
