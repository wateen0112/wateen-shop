/// Login screen — the counterpart of `pages/Login.jsx`.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.login(_username.text.trim(), _password.text);
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
        _error = 'تعذّر تسجيل الدخول';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x1A0F172A), blurRadius: 28, offset: Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Column(
                    children: <Widget>[
                      _BrandMark(size: 66),
                      SizedBox(height: 12),
                      Text(
                        'أبو وتين',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'سجّل الدخول للمتابعة',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (_error != null) MsgBox(text: _error!),
                  AppField(
                    label: 'اسم المستخدم',
                    controller: _username,
                    hint: 'admin',
                    textInputAction: TextInputAction.next,
                  ),
                  AppField(
                    label: 'كلمة المرور',
                    controller: _password,
                    hint: '••••••',
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {},
                  ),
                  AppButton(
                    _busy ? 'جارٍ الدخول...' : 'تسجيل الدخول',
                    busy: _busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'اطلب من الأدمن إنشاء حساب لك وتحديد صلاحياتك',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[AppColors.primary, AppColors.primary600, Color(0xFF14B8A6)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.store_rounded, color: Colors.white, size: size * 0.55),
    );
  }
}

/// Shared brand mark used by the login card and the app bar.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => _BrandMark(size: size);
}
