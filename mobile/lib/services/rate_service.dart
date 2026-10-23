/// USD → SYP exchange rate (public endpoint).
library;

import '../core/api_client.dart';
import '../models/models.dart';

class RateService {
  RateService(this.api);

  final ApiClient api;

  /// `GET /api/rate` → `{ usdToSyp, source }`.
  Future<RateInfo> get() async {
    final data = await api.get('/rate') as Map<String, dynamic>;
    return RateInfo.fromJson(data);
  }
}
