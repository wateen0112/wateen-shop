/// Customers & debts endpoints.
library;

import '../core/api_client.dart';
import '../models/models.dart';

class CustomersService {
  CustomersService(this.api);

  final ApiClient api;

  /// `GET /api/customers` — every customer with their computed balance.
  Future<List<Customer>> list() async {
    final data = await api.get('/customers') as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(Customer.fromJson).toList();
  }

  /// `GET /api/customers/:id` — the customer with the full movement history.
  Future<Customer> get(String id) async {
    final data = await api.get('/customers/$id') as Map<String, dynamic>;
    return Customer.fromJson(data);
  }

  Future<Customer> create({
    required String name,
    required String phone,
    required String note,
    required double initialBalance,
  }) async {
    final data = await api.post('/customers', body: <String, dynamic>{
      'name': name,
      'phone': phone,
      'note': note,
      'initialBalance': initialBalance,
    }) as Map<String, dynamic>;
    return Customer.fromJson(data);
  }

  Future<Customer> update(
    String id, {
    required String name,
    required String phone,
    required String note,
    required double initialBalance,
  }) async {
    final data = await api.put('/customers/$id', body: <String, dynamic>{
      'name': name,
      'phone': phone,
      'note': note,
      'initialBalance': initialBalance,
    }) as Map<String, dynamic>;
    return Customer.fromJson(data);
  }

  Future<void> delete(String id) async {
    await api.delete('/customers/$id');
  }

  /// `POST /api/customers/:id/debt` — `type` is `debit` or `credit`.
  Future<DebtMovement> addDebt(
    String customerId, {
    required String type,
    required double amount,
    String note = '',
  }) async {
    final data = await api.post('/customers/$customerId/debt', body: <String, dynamic>{
      'type': type,
      'amount': amount,
      'note': note,
    }) as Map<String, dynamic>;
    return DebtMovement.fromJson(data);
  }

  Future<void> deleteDebt(String customerId, String debtId) async {
    await api.delete('/customers/$customerId/debt/$debtId');
  }
}
