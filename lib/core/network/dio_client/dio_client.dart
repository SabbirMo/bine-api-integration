import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/network/auth_interceptor/auth_interceptor.dart';
import 'package:dio/dio.dart';

class DioClient {
  static Dio? _dio;

  // Singleton pattern to ensure only one instance of Dio is used throughout the app
  static Dio get instance {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: BaseUrl.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      _dio!.interceptors.add(AuthInterceptor(_dio!));
    }
    return _dio!;
  }

  //login and signup api calls should not have auth interceptor
  static Dio get instanceWithoutAuth {
    return Dio(
        BaseOptions(
          baseUrl: BaseUrl.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      )
      ..interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          requestHeader: true,
          responseHeader: false,
        ),
      );
  }

  static void reset() {
    _dio?.close();
    _dio = null;
  }
}
