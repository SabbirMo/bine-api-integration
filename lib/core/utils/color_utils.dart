import 'package:flutter/material.dart';

class AppColorUtils {
  AppColorUtils._();

  /// Safely parses hex string (#RGB, #RRGGBB, #AARRGGBB, 0xRRGGBB) to Color.
  /// Never throws FormatException. Returns [fallback] on failure.
  static Color fromHex(dynamic hex, {Color fallback = Colors.transparent}) {
    if (hex == null) return fallback;
    var str = hex.toString().trim().toUpperCase();
    if (str.isEmpty) return fallback;

    if (str.startsWith('0X')) {
      str = str.substring(2);
    } else if (str.startsWith('#')) {
      str = str.substring(1);
    }

    // Handle 3-character hex shorthand (#RGB -> #RRGGBB)
    if (str.length == 3) {
      str = '${str[0]}${str[0]}${str[1]}${str[1]}${str[2]}${str[2]}';
    }

    // Handle 6-character RGB -> add full opacity FF
    if (str.length == 6) {
      str = 'FF$str';
    }

    if (str.length != 8) return fallback;

    final intVal = int.tryParse(str, radix: 16);
    if (intVal == null) return fallback;

    return Color(intVal);
  }
}
