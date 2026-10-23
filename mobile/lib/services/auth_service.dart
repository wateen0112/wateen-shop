/// Auth + permissions endpoints — mirrors `frontend/src/api.js` (auth section).
library;

import '../core/api_client.dart';
import '../core/permissions.dart';
import '../models/models.dart';

class AuthService {
  AuthService(this.api);

  final ApiClient api;

  /// `POST /api/auth/login` → `{ token, user }`.
  Future<({String token, AppUser user})> login(String username, String password) async {
    final data = await api.post('/auth/login', body: <String, dynamic>{
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;
    return (
      token: data['token'].toString(),
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  /// `GET /api/auth/me`.
  Future<AppUser> me() async {
    final data = await api.get('/auth/me') as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  /// `GET /api/auth/permissions` — public catalogue used by the admin matrix.
  Future<List<Permission>> permissions() async {
    final data = await api.get('/auth/permissions') as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map((Map<String, dynamic> json) {
      return Permission(
        json['key'].toString(),
        json['label'].toString(),
        json['group'].toString(),
      );
    }).toList();
  }

  /// `POST /api/auth/logout` — records the event in the audit log.
  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
  }

  /// `POST /api/auth/change-password`.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await api.post('/auth/change-password', body: <String, dynamic>{
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
