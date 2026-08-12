import 'package:binetatour/core/network/error/api_exception.dart';
import 'package:dio/dio.dart';

class ApiErrorHandle {
  static ApiException handleError(dynamic error) {
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;
      final statusCode = response?.statusCode;

      final validationMessage = _extractValidationMessage(data);
      if (validationMessage != null && validationMessage.isNotEmpty) {
        return ApiException(
          message: sanitizeMessage(validationMessage, statusCode),
          statusCode: statusCode,
        );
      }

      final message = _extractMessage(data, statusCode);

      return ApiException(
        message: sanitizeMessage(message, statusCode),
        statusCode: statusCode,
      );
    }

    if (error is Exception) {
      return ApiException(
        message: sanitizeMessage(
          error.toString().replaceAll('Exception: ', ''),
          null,
        ),
      );
    }

    return ApiException(message: 'Une erreur inattendue s\'est produite');
  }

  static String _extractMessage(dynamic data, int? statusCode) {
    if (data is String) {
      if (_isHtml(data)) {
        return _cleanHtmlString(data, statusCode);
      }
      return data;
    }

    if (data is Map) {
      if (data['message'] != null) {
        final msg = data['message'].toString();
        if (_isHtml(msg)) return _cleanHtmlString(msg, statusCode);
        return msg;
      }

      if (data['error'] != null) {
        final err = data['error'].toString();
        if (_isHtml(err)) return _cleanHtmlString(err, statusCode);
        return err;
      }

      if (data['detail'] != null) {
        final det = data['detail'].toString();
        if (_isHtml(det)) return _cleanHtmlString(det, statusCode);
        return det;
      }

      if (data['non_field_errors'] != null) {
        if (data['non_field_errors'] is List) {
          return (data['non_field_errors'] as List).join('\n');
        }
        final nfe = data['non_field_errors'].toString();
        if (_isHtml(nfe)) return _cleanHtmlString(nfe, statusCode);
        return nfe;
      }

      // If it's a Map but doesn't have the common keys above, parse it as a raw map of field validation errors.
      final mapMessage = _mapToMessage(data);
      if (mapMessage.isNotEmpty) {
        return mapMessage;
      }
    }

    if (statusCode != null && statusCode >= 500) {
      return "Server Error ($statusCode)";
    }

    return data != null ? data.toString() : 'An unexpected error occurred';
  }

  static String sanitizeMessage(String message, int? statusCode) {
    if (_isHtml(message)) {
      return _cleanHtmlString(message, statusCode);
    }
    return message;
  }

  static bool _isHtml(String str) {
    if (str.isEmpty) return false;
    final lower = str.toLowerCase().trim();
    return lower.startsWith('<!doctype') ||
        lower.contains('<html') ||
        lower.contains('<head') ||
        lower.contains('<body') ||
        lower.contains('<title>') ||
        lower.contains('<h1>') ||
        lower.contains('</') ||
        RegExp(r'<[a-zA-Z/][^>]*>').hasMatch(str);
  }

  static String _cleanHtmlString(String htmlStr, int? statusCode) {
    // 1. Try to extract <title> text
    final titleMatch = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(htmlStr);
    if (titleMatch != null && titleMatch.group(1) != null) {
      final titleText = titleMatch
          .group(1)!
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      if (titleText.isNotEmpty) {
        return titleText;
      }
    }

    // 2. Try to extract <h1> text
    final h1Match = RegExp(
      r'<h1[^>]*>(.*?)</h1>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(htmlStr);
    if (h1Match != null && h1Match.group(1) != null) {
      final h1Text = h1Match
          .group(1)!
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      if (h1Text.isNotEmpty) {
        return h1Text;
      }
    }

    // 3. Strip all HTML tags
    String plainText = htmlStr.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    // Replace multiple spaces/newlines with single space
    plainText = plainText.replaceAll(RegExp(r'\s+'), ' ');

    if (plainText.isNotEmpty && plainText.length <= 120) {
      return plainText;
    }

    if (statusCode != null) {
      return "Server Error ($statusCode)";
    }

    return "Server Error";
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
