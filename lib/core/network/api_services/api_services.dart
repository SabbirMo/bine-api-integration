import 'package:binetatour/core/network/dio_client/dio_client.dart';
import 'package:binetatour/core/network/error/api_error_handle.dart';
import 'package:dio/dio.dart';

class ApiServices {
  Dio dio(bool requireAuth) {
    return requireAuth ? DioClient.instance : DioClient.instanceWithoutAuth;
  }

  Future<Response> post(
    String path, {
    dynamic data,
    bool requireAuth = true,
  }) async {
    try {
      return await dio(requireAuth).post(path, data: data);
    } on DioException catch (e) {
      throw ApiErrorHandle.handleError(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requireAuth = true,
  }) async {
    try {
      return await dio(requireAuth).get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiErrorHandle.handleError(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    bool requireAuth = true,
  }) async {
    try {
      return await dio(requireAuth).patch(path, data: data);
    } on DioException catch (e) {
      throw ApiErrorHandle.handleError(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Response> delete(String path, {bool requireAuth = true}) async {
    try {
      return await dio(requireAuth).delete(path);
    } on DioException catch (e) {
      throw ApiErrorHandle.handleError(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
