/// Thin HTTP layer over Dio — mirrors `frontend/src/api.js`:
///  * every call hits `/api/...` on the same backend,
///  * the Bearer token is attached automatically,
///  * a `401` clears the session and logs the user out,
///  * server errors surface the Arabic `error` message returned by Express.
library;

import 'package:dio/dio.dart';

import 'session.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.session, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                headers: <String, dynamic>{'Content-Type': 'application/json'},
                responseType: ResponseType.json,
                validateStatus: (int? code) => code != null && code >= 200 && code < 300,
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final token = session.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) {
          if (error.response?.statusCode == 401) {
            _unauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final String baseUrl;
  final SessionStore session;
  final Dio _dio;

  /// Invoked when the server rejects the token (expired / disabled account).
  void Function()? _unauthorized;

  set onUnauthorized(void Function()? handler) => _unauthorized = handler;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete<dynamic>(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final Response<dynamic> response = await request();
      return response.data;
    } on DioException catch (error) {
      throw ApiException(_messageOf(error), status: error.response?.statusCode);
    } catch (_) {
      throw ApiException('تعذّر الاتصال بالخادم');
    }
  }

  String _messageOf(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is String && err.trim().isNotEmpty) return err;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'تعذّر الاتصال بالخادم';
    }
    return 'حدث خطأ غير متوقع';
  }
}
