import 'dart:developer';

import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  static const String _retryFlag = '_hasRetriedAfterRefresh';

  AuthInterceptor(this.dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await TokenStorage.getAccessToken();
    if (kDebugMode) {
      log(
        'onRequest: Access token retrieved (isPresent: ${accessToken != null && accessToken.isNotEmpty}) for path: ${options.path}',
      );
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
      if (kDebugMode) {
        log('onRequest: Bearer token attached');
      }
    } else {
      if (kDebugMode) {
        log(
          'WARNING: Access token is null or empty for request to ${options.path}',
        );
      }
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final isRefreshRequest = request.path.contains(
      '/api/mobile/auth/token/refresh/',
    );
    final hasRetried = request.extra[_retryFlag] == true;

    if (isUnauthorized && !isRefreshRequest && !hasRetried) {
      final refreshed = await refreshToken();
      if (refreshed) {
        try {
          final accessToken = await TokenStorage.getAccessToken();

          request.extra[_retryFlag] = true;
          request.headers['Authorization'] = 'Bearer $accessToken';

          final response = await dio.fetch(request);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      } else {
        // Clear stored tokens when token refresh fails on 401
        await TokenStorage.clearTokens();
        return handler.next(err);
      }
    } else if (isUnauthorized) {
      // Clear stored tokens if refresh request itself failed with 401 or hasRetried
      await TokenStorage.clearTokens();
    }
    return handler.next(err);
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: BaseUrl.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        '/api/mobile/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );

      final body = response.data;
      final data = body is Map<String, dynamic>
          ? (body['data'] is Map<String, dynamic>
                ? body['data'] as Map<String, dynamic>
                : body)
          : <String, dynamic>{};

      final newAccessToken = data['access']?.toString();
      final newRefreshToken = data['refresh']?.toString();

      if (newAccessToken == null || newAccessToken.isEmpty) {
        return false;
      }

      await TokenStorage.saveAccessToken(newAccessToken);

      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await TokenStorage.saveRefreshToken(newRefreshToken);
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
