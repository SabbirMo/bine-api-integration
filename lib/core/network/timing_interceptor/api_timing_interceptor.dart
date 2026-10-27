import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:binetatour/core/network/network_status_service.dart';

/// Interceptor that measures and logs the load time (in seconds and milliseconds)
/// for each API request, and feeds live latency metrics into NetworkStatusService.
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
      final cfCache = response.headers.value('cf-cache-status') ?? 'N/A';
      final cfRay = response.headers.value('cf-ray') ?? 'N/A';
      if (kDebugMode) {
        debugPrint(
          '⏱️ [API LOAD TIME] [${response.requestOptions.method}] ${response.requestOptions.path} '
          '-> ${seconds}s (${ms}ms) | Status: ${response.statusCode} | CF-Cache: $cfCache | CF-RAY: $cfRay',
        );
      }

      // Feed live network health: if an API call takes > 4.5s, report slow network
      if (ms > 4500) {
        NetworkStatusService.instance.reportSlow(
          reason: 'Temps de réponse API élevé (${seconds}s)',
        );
      } else {
        NetworkStatusService.instance.reportOnline();
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

    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      NetworkStatusService.instance.reportOffline(
        reason: 'Échec de connexion (${err.type.name})',
      );
    } else if (err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      NetworkStatusService.instance.reportSlow(
        reason: 'Délai réseau dépassé (${err.type.name})',
      );
    }

    super.onError(err, handler);
  }
}
