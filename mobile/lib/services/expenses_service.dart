/// Expenses endpoints.
library;

import '../core/api_client.dart';
import '../models/models.dart';

class ExpensesService {
  ExpensesService(this.api);

  final ApiClient api;

  Future<List<Expense>> list() async {
    final data = await api.get('/expenses') as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(Expense.fromJson).toList();
  }

  Future<Expense> create({
    required String title,
    required double amount,
    required String currency,
    String note = '',
  }) async {
    final data = await api.post('/expenses', body: <String, dynamic>{
      'title': title,
      'amount': amount,
      'currency': currency,
      'note': note,
    }) as Map<String, dynamic>;
    return Expense.fromJson(data);
  }

  Future<void> delete(String id) async {
    await api.delete('/expenses/$id');
  }

  /// `GET /api/expenses/total` — total expenses converted to SYP.
  Future<double> total() async {
    final data = await api.get('/expenses/total') as Map<String, dynamic>;
    return (data['totalSYP'] as num?)?.toDouble() ?? 0;
  }
}
