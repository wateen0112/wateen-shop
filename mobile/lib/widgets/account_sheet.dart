/// Account sheet — the counterpart of the `AccountSheet` component in `App.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_services.dart';
import '../core/permissions.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

class AccountSheet extends StatefulWidget {
  const AccountSheet({
    super.key,
    required this.user,
    required this.catalog,
    required this.onLogout,
    this.onManageUsers,
  });

  final AppUser user;
  final List<Permission> catalog;
  final VoidCallback onLogout;
  final VoidCallback? onManageUsers;

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await AppServices.instance.auth.changePassword(_current.text, _next.text);
      _current.clear();
      _next.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = 'تم تغيير كلمة المرور';
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
        _error = 'تعذّر تغيير كلمة المرور';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Permission> labels =
        widget.catalog.where((Permission p) => p.key != 'users.manage').toList();
    final List<Permission> owned = widget.user.isAdmin
        ? labels
        : labels.where((Permission p) => widget.user.permissions.contains(p.key)).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'حسابي',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                AppIconButton(
                  icon: Icons.close_rounded,
                  color: AppColors.muted,
                  background: AppColors.softGrey,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.user.name.isNotEmpty ? widget.user.name : widget.user.username,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${widget.user.username} — ${widget.user.isAdmin ? 'أدمن' : 'مستخدم'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.user.isAdmin && widget.onManageUsers != null)
              AppButton(
                'إدارة المستخدمين والصلاحيات',
                kind: AppButtonKind.secondary,
                icon: Icons.shield_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onManageUsers!();
                },
              ),
            const SizedBox(height: 16),
            const Text(
              'صلاحياتك',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            if (owned.isEmpty)
              const HintText('لا توجد صلاحيات — اطلب من الأدمن')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: owned.map((Permission p) => Pill(p.label)).toList(),
              ),
            const SizedBox(height: 18),
            if (_error != null) MsgBox(text: _error!),
            if (_success != null) MsgBox(text: _success!, type: MsgType.success),
            AppField(
              label: 'كلمة المرور الحالية',
              controller: _current,
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),
            AppField(
              label: 'كلمة المرور الجديدة',
              controller: _next,
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),
            AppButton(
              _busy ? 'جارٍ الحفظ…' : 'حفظ كلمة المرور',
              kind: AppButtonKind.secondary,
              busy: _busy,
              onPressed: (_current.text.isEmpty || _next.text.length < 4) ? null : _changePassword,
            ),
            const SizedBox(height: 10),
            AppButton(
              'تسجيل الخروج',
              kind: AppButtonKind.danger,
              icon: Icons.logout_rounded,
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
