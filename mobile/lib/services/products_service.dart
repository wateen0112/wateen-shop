/// Products & barcodes endpoints.
library;

import '../core/api_client.dart';
import '../models/models.dart';

class ProductsService {
  ProductsService(this.api);

  final ApiClient api;

  /// `GET /api/products?search=…` — the backend searches by name or exact barcode.
  Future<List<Product>> list({String? search}) async {
    final data = await api.get('/products', query: <String, dynamic>{
      if (search != null && search.isNotEmpty) 'search': search,
    }) as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
  }

  /// `GET /api/products/no-barcode` — products without a valid GTIN barcode.
  Future<List<Product>> noBarcode() async {
    final data = await api.get('/products/no-barcode') as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
  }

  /// `POST /api/products` — an empty/invalid barcode is generated server-side.
  Future<Product> create({
    required String name,
    required String barcode,
    required String unit,
    required double quantity,
    required double purchasePrice,
    required String purchaseCurrency,
    double? salePrice,
  }) async {
    final data = await api.post('/products', body: <String, dynamic>{
      'name': name,
      'barcode': barcode,
      'unit': unit,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'purchaseCurrency': purchaseCurrency,
      'salePrice': ?salePrice,
    }) as Map<String, dynamic>;
    return Product.fromJson(data);
  }

  Future<Product> update(
    String id, {
    required String name,
    required String barcode,
    required String unit,
    required double quantity,
    required double purchasePrice,
    required String purchaseCurrency,
  }) async {
    final data = await api.put('/products/$id', body: <String, dynamic>{
      'name': name,
      'barcode': barcode,
      'unit': unit,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'purchaseCurrency': purchaseCurrency,
    }) as Map<String, dynamic>;
    return Product.fromJson(data);
  }

  Future<void> delete(String id) async {
    await api.delete('/products/$id');
  }

  /// `POST /api/products/:id/sale-price` — appends a new price to the history.
  Future<Product> addSalePrice(String id, double price, String note) async {
    final data = await api.post('/products/$id/sale-price', body: <String, dynamic>{
      'price': price,
      'note': note,
    }) as Map<String, dynamic>;
    return Product.fromJson(data);
  }

  /// `POST /api/products/generate-barcodes` — `all: true` targets every product.
  Future<List<BarcodeResult>> generateBarcodes({List<String> ids = const <String>[], bool all = false}) async {
    final data = await api.post('/products/generate-barcodes', body: <String, dynamic>{
      'ids': ids,
      'all': all,
    }) as List<dynamic>;
    return data.whereType<Map<String, dynamic>>().map(BarcodeResult.fromJson).toList();
  }
}
