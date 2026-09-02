import 'package:intl/intl.dart';

class AppPriceUtils {
  AppPriceUtils._();

  static final NumberFormat _currencyFormatter =
      NumberFormat('#,##0', 'fr_FR');

  /// Safely parses dynamic price representation
  static double parsePrice(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();

    var clean = value.toString().trim();
    if (clean.isEmpty) return fallback;

    clean = clean.replaceAll(RegExp(r'[^\d.,-]'), '');
    clean = clean.replaceAll(' ', '').replaceAll(',', '.');

    return double.tryParse(clean) ?? fallback;
  }

  /// Parses discount percentage safely
  static double parseDiscountPercentage(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final clean =
        value.toString().replaceAll('%', '').replaceAll(',', '.').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  /// Formats price into standard display string (e.g. 10000 -> "10 000 FCFA").
  static String formatPrice(
    dynamic value, {
    String currency = 'FCFA',
    bool includeCurrency = true,
  }) {
    final numVal = parsePrice(value, 0.0);
    final formattedNum =
        _currencyFormatter.format(numVal).replaceAll('\u00A0', ' ');

    if (!includeCurrency || currency.isEmpty) {
      return formattedNum;
    }
    return '$formattedNum $currency';
  }
}
