/// Session state — mirrors `frontend/src/context/AuthContext.jsx`.
library;

import 'package:flutter/foundation.dart';

import '../core/app_services.dart';
import '../core/session.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({SessionStore? session, AuthService? service})
      : _session = session ?? AppServices.instance.session,
        _service = service ?? AppServices.instance.auth;

  final SessionStore _session;
  final AuthService _service;

  AppUser? _user;
  bool _booting = true;

  AppUser? get user => _user;
  bool get booting => _booting;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// The permission check used everywhere in the UI (`can('products.view')`).
  bool can(String key) => _user?.can(key) ?? false;

  /// Restores a stored session on start-up.
  Future<void> boot() async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      _booting = false;
      notifyListeners();
      return;
    }
    try {
      _user = await _service.me();
    } catch (_) {
      await _session.clear();
      _user = null;
    }
    _booting = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final result = await _service.login(username, password);
    await _session.save(result.token, result.user);
    _user = result.user;
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    await _session.clear();
    _user = null;
    notifyListeners();
  }

  /// Called when the API answers 401 — the session expired or was disabled.
  Future<void> handleUnauthorized() async {
    if (_user == null) return;
    await _session.clear();
    _user = null;
    notifyListeners();
  }
}
