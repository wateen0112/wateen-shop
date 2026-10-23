/// Service container — one instance created in `main()` and shared by the app.
library;

import 'api_client.dart';
import 'session.dart';
import '../services/auth_service.dart';
import '../services/audit_service.dart';
import '../services/cashbox_service.dart';
import '../services/customers_service.dart';
import '../services/expenses_service.dart';
import '../services/inventory_service.dart';
import '../services/products_service.dart';
import '../services/rate_service.dart';
import '../services/sales_service.dart';
import '../services/users_service.dart';

class AppServices {
  AppServices._(this.session, this.api)
      : auth = AuthService(api),
        users = UsersService(api),
        audit = AuditService(api),
        products = ProductsService(api),
        sales = SalesService(api),
        expenses = ExpensesService(api),
        inventory = InventoryService(api),
        customers = CustomersService(api),
        cashbox = CashboxService(api),
        rate = RateService(api);

  /// The base URL of the backend. Override at build time:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000/api`
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.105:5000/api',
  );

  static AppServices? _instance;

  static AppServices get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AppServices.instance was used before init()');
    }
    return value;
  }

  static Future<AppServices> init({String baseUrl = defaultBaseUrl}) async {
    final session = await SessionStore.open();
    final api = ApiClient(baseUrl: baseUrl, session: session);
    final services = AppServices._(session, api);
    _instance = services;
    return services;
  }

  final SessionStore session;
  final ApiClient api;
  final AuthService auth;
  final UsersService users;
  final AuditService audit;
  final ProductsService products;
  final SalesService sales;
  final ExpensesService expenses;
  final InventoryService inventory;
  final CustomersService customers;
  final CashboxService cashbox;
  final RateService rate;
}
