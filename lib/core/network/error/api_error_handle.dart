import 'package:binetatour/core/network/error/api_exception.dart';
import 'package:dio/dio.dart';

class ApiErrorHandle {
  static ApiException handleError(dynamic error) {
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;

      final validationMessage = _extractValidationMessage(data);
      if (validationMessage != null && validationMessage.isNotEmpty) {
        return ApiException(
          message: validationMessage,
          statusCode: response?.statusCode,
        );
      }

      final message = _extractMessage(data);

      return ApiException(message: message, statusCode: response?.statusCode);
    }

    return ApiException(message: 'An unexpected error occurred');
  }

  static String _extractMessage(dynamic data) {
    if (data is String) return data;

    if (data is Map) {
      if (data['message'] != null) {
        return data['message'].toString();
      }

      if (data['error'] != null) {
        return data['error'].toString();
      }

      if (data['detail'] != null) {
        return data['detail'].toString();
      }

      if (data['non_field_errors'] != null) {
        if (data['non_field_errors'] is List) {
          return (data['non_field_errors'] as List).join('\n');
        }
        return data['non_field_errors'].toString();
      }

      // If it's a Map but doesn't have the common keys above, parse it as a raw map of field validation errors.
      final mapMessage = _mapToMessage(data);
      if (mapMessage.isNotEmpty) {
        return mapMessage;
      }
    }
    return data != null ? data.toString() : 'An unexpected error occurred';
  }

  static String? _extractValidationMessage(dynamic data) {
    if (data is! Map) return null;

    // case: errors
    if (data['errors'] is Map) {
      return _mapToMessage(data['errors']);
    }

    // case: data (your backend case)
    if (data['data'] is Map) {
      return _mapToMessage(data['data']);
    }

    return null;
  }

  static String _mapToMessage(Map map) {
    final messages = <String>[];

    for (var value in map.values) {
      if (value is List) {
        messages.addAll(value.map((e) => e.toString()));
      } else if (value is Map) {
        final nested = _mapToMessage(value);
        if (nested.isNotEmpty) {
          messages.add(nested);
        }
      } else if (value != null) {
        messages.add(value.toString());
      }
    }

    return messages.join('\n');
  }
}
