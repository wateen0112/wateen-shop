/// Cash box endpoints.
library;

import '../core/api_client.dart';
import '../models/models.dart';

class CashboxService {
  CashboxService(this.api);

  final ApiClient api;

  /// `GET /api/cashbox` — the full summary (balances, profit, debts).
  Future<CashboxSummary> summary() async {
    final data = await api.get('/cashbox') as Map<String, dynamic>;
    return CashboxSummary.fromJson(data);
  }

  /// `PUT /api/cashbox` — sets the opening balance of the main cash box.
  Future<CashboxSummary> setInitialBalance(double initialBalance) async {
    final data = await api.put('/cashbox', body: <String, dynamic>{
      'initialBalance': initialBalance,
    }) as Map<String, dynamic>;
    return CashboxSummary.fromJson(data);
  }
}
