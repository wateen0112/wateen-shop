/// Persisted session (token + signed-in user) — the Flutter equivalent of the
/// `localStorage` usage of the React app.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class SessionStore {
  SessionStore(this._prefs);

  static const String _tokenKey = 'wateen_token';
  static const String _userKey = 'wateen_user';

  final SharedPreferences _prefs;

  String? get token => _prefs.getString(_tokenKey);

  AppUser? get user {
    final raw = _prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String token, AppUser user) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }

  static Future<SessionStore> open() async =>
      SessionStore(await SharedPreferences.getInstance());
}
