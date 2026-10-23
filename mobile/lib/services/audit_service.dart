/// Audit log endpoints (admin only).
library;

import '../core/api_client.dart';
import '../models/models.dart';

String _day(DateTime date) {
  final String m = date.month.toString().padLeft(2, '0');
  final String d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

class AuditService {
  AuditService(this.api);

  final ApiClient api;

  Future<AuditPage> list({
    int page = 1,
    int limit = 30,
    String q = '',
    String? action,
    String? entity,
    String? userId,
    DateTime? from,
    DateTime? to,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{'page': page, 'limit': limit};
    if (q.trim().isNotEmpty) query['q'] = q.trim();
    if (action != null && action.isNotEmpty) query['action'] = action;
    if (entity != null && entity.isNotEmpty) query['entity'] = entity;
    if (userId != null && userId.isNotEmpty) query['userId'] = userId;
    if (from != null) query['from'] = _day(from);
    if (to != null) query['to'] = _day(to);

    final data = await api.get('/audit', query: query) as Map<String, dynamic>;
    return AuditPage.fromJson(data);
  }

  Future<AuditMeta> meta() async {
    final data = await api.get('/audit/meta') as Map<String, dynamic>;
    return AuditMeta.fromJson(data);
  }

  Future<AuditEntry> entry(String id) async {
    final data = await api.get('/audit/$id') as Map<String, dynamic>;
    return AuditEntry.fromJson(data);
  }
}
