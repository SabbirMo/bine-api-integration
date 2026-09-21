import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Transparent Auto-Retry Interceptor for idempotent GET requests.
/// Automatically recovers from momentary device network drops, DNS wake-up stalls,
/// and cellular connection timeouts without requiring manual pull-to-refresh.
class NetworkRetryInterceptor extends Interceptor {
  final Dio dio;
  static const String _retryCountKey = '_retry_count';
  static const int _maxRetries = 1;

  NetworkRetryInterceptor(this.dio);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final isGet = req.method.toUpperCase() == 'GET';
    final isConnectionIssue =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError;

    final currentRetries = (req.extra[_retryCountKey] as int?) ?? 0;

    if (isGet && isConnectionIssue && currentRetries < _maxRetries) {
      req.extra[_retryCountKey] = currentRetries + 1;
      debugPrint(
        '🔄 [NetworkRetryInterceptor] Momentary connection drop on ${req.uri}. Auto-recovering in 1.5s (Attempt ${currentRetries + 1}/$_maxRetries)...',
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final response = await dio.fetch(req);
        return handler.resolve(response);
      } catch (e) {
        if (e is DioException) {
          return handler.next(e);
        }
      }
    }

    return handler.next(err);
  }
}
