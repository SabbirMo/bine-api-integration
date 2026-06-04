class GetResponseMessage {
  String getResponseMessage(dynamic body) {
    if (body == null) {
      return 'Operation completed successfully.';
    }

    if (body is String) {
      return body;
    }

    if (body is Map) {
      final data = body['data'];

      if (data is Map) {
        for (final value in data.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
        }
      }

      final message = body['message'];
      if (message != null) {
        return message.toString();
      }
    }

    return "An unknown error occurred.";
  }
}
