/// Sales & profit endpoints.
library;

import '../core/api_client.dart';
import '../models/models.dart';

class SalesService {
  SalesService(this.api);

  final ApiClient api;

  /// `POST /api/sales` — sells by barcode, product id, or product name.
  /// When `onCredit` is true the sale is registered as a debt for `customerId`.
  Future<Sale> create({
    String? barcode,
    String? name,
    String? productId,
    int quantity = 1,
    bool onCredit = false,
    String? customerId,
  }) async {
    final data = await api.post('/sales', body: <String, dynamic>{
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      if (name != null && name.isNotEmpty) 'name': name,
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      'quantity': quantity,
      'onCredit': onCredit,
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
    }) as Map<String, dynamic>;
    return Sale.fromJson(data);
  }

  /// `GET /api/sales/profit` — net profit of every sale, in SYP.
  Future<ProfitSummary> profit() async {
    final data = await api.get('/sales/profit') as Map<String, dynamic>;
    return ProfitSummary.fromJson(data);
  }
}
