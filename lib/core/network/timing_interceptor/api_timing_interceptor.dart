import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor that measures and logs the load time (in seconds and milliseconds)
/// for each API request.
class ApiTimingInterceptor extends Interceptor {
  static const String _stopwatchKey = '_api_timing_stopwatch';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchKey] = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint('🚀 [API START] [${options.method}] ${options.uri}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final stopwatch = response.requestOptions.extra[_stopwatchKey] as Stopwatch?;
    if (stopwatch != null) {
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      final seconds = (ms / 1000).toStringAsFixed(2);
      if (kDebugMode) {
        debugPrint(
          '⏱️ [API LOAD TIME] [${response.requestOptions.method}] ${response.requestOptions.path} '
          '-> ${seconds}s (${ms}ms) | Status: ${response.statusCode}',
        );
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final stopwatch = err.requestOptions.extra[_stopwatchKey] as Stopwatch?;
    if (stopwatch != null) {
      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      final seconds = (ms / 1000).toStringAsFixed(2);
      if (kDebugMode) {
        debugPrint(
          '❌ [API LOAD TIME - FAILED] [${err.requestOptions.method}] ${err.requestOptions.path} '
          '-> failed after ${seconds}s (${ms}ms) | Status: ${err.response?.statusCode ?? 'N/A'} | Error: ${err.message ?? err.type}',
        );
      }
    }
    super.onError(err, handler);
  }
}
