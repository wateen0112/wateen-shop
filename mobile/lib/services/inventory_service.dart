/// Inventory endpoints.
library;

import '../core/api_client.dart';
import '../models/models.dart';

class InventoryService {
  InventoryService(this.api);

  final ApiClient api;

  /// `GET /api/inventory/sheet` — the products to count.
  Future<List<Product>> sheet() async {
    final data = await api.get('/inventory/sheet') as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
  }

  /// `POST /api/inventory` — saves the counted quantities and overwrites the stock.
  Future<InventorySnapshot> save({
    required List<({String productId, double actualQty})> items,
    String note = '',
  }) async {
    final data = await api.post('/inventory', body: <String, dynamic>{
      'items': items
          .map((({String productId, double actualQty}) item) => <String, dynamic>{
                'productId': item.productId,
                'actualQty': item.actualQty,
              })
          .toList(),
      'note': note,
    }) as Map<String, dynamic>;
    return InventorySnapshot.fromJson(data);
  }

  /// `GET /api/inventory` — past snapshots, newest first.
  Future<List<InventorySnapshot>> snapshots() async {
    final data = await api.get('/inventory') as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(InventorySnapshot.fromJson).toList();
  }
}
