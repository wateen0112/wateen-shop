/// Users & permissions endpoints.
library;

import '../core/api_client.dart';
import '../models/models.dart';

class UsersService {
  UsersService(this.api);

  final ApiClient api;

  Future<List<AppUser>> list() async {
    final data = await api.get('/users') as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(AppUser.fromJson).toList();
  }

  Future<AppUser> create({
    required String username,
    required String name,
    required String password,
    required String role,
    required List<String> permissions,
  }) async {
    final data = await api.post('/users', body: <String, dynamic>{
      'username': username,
      'name': name,
      'password': password,
      'role': role,
      'permissions': permissions,
    }) as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  Future<AppUser> update({
    required String id,
    required String name,
    required String role,
    required List<String> permissions,
    required bool active,
    String? password,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'role': role,
      'permissions': permissions,
      'active': active,
    };
    if (password != null && password.isNotEmpty) body['password'] = password;
    final data = await api.put('/users/$id', body: body) as Map<String, dynamic>;
    return AppUser.fromJson(data);
  }

  Future<void> delete(String id) async {
    await api.delete('/users/$id');
  }
}
