import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/network/auth_interceptor/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DioClient {
  static Dio? _dio;
  static Dio? _dioWithoutAuth;

  // Singleton pattern to ensure only one instance of Dio is used throughout the app
  static Dio get instance {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: BaseUrl.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 5),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      _dio!.interceptors.add(AuthInterceptor(_dio!));
      if (kDebugMode) {
        _dio!.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            error: true,
            requestHeader: true,
            responseHeader: false,
          ),
        );
      }
    }
    return _dio!;
  }

  // Login and signup api calls should not have auth interceptor.
  // Cached as singleton to enable TCP/TLS connection reuse and HTTP Keep-Alive.
  static Dio get instanceWithoutAuth {
    if (_dioWithoutAuth == null) {
      final dio = Dio(
        BaseOptions(
          baseUrl: BaseUrl.baseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        dio.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            error: true,
            requestHeader: true,
            responseHeader: false,
          ),
        );
      }
      _dioWithoutAuth = dio;
    }
    return _dioWithoutAuth!;
  }

  static void reset() {
    _dio?.close();
    _dio = null;
    _dioWithoutAuth?.close();
    _dioWithoutAuth = null;
  }
}
