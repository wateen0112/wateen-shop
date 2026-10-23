/// Root widget — session gate, RTL/Arabic locale and the app theme.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_services.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'state/auth_controller.dart';
import 'state/auth_scope.dart';

class WateenApp extends StatefulWidget {
  const WateenApp({super.key, required this.services});

  final AppServices services;

  @override
  State<WateenApp> createState() => _WateenAppState();
}

class _WateenAppState extends State<WateenApp> {
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = AuthController();
    widget.services.api.onUnauthorized = () {
      _auth.handleUnauthorized();
    };
    _auth.boot();
  }

  @override
  void dispose() {
    widget.services.api.onUnauthorized = null;
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: MaterialApp(
        title: 'أبو وتين',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ar', 'SY'),
        supportedLocales: const <Locale>[
          Locale('ar', 'SY'),
          Locale('ar'),
          Locale('en'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (BuildContext context, Widget? child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: ListenableBuilder(
          listenable: _auth,
          builder: (BuildContext context, Widget? _) {
            if (_auth.booting) return const _BootScreen();
            if (!_auth.isAuthenticated) return LoginScreen(auth: _auth);
            return HomeShell(auth: _auth);
          },
        ),
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.appBarGradient,
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            const Text(
              'أبو وتين',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'جارٍ التحميل...',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
