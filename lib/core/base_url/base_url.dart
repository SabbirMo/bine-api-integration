import 'package:flutter_dotenv/flutter_dotenv.dart';

class BaseUrl {
  static String get baseUrl =>
      dotenv.env['API_URL'] ?? '';
}
