import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _isoTimeFormat = DateFormat('HH:mm:ss.SSS');

  /// Safely parses dynamic date input (String, DateTime, int milliseconds) into DateTime?
  static DateTime? tryParseDateTime(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    if (input is int) return DateTime.fromMillisecondsSinceEpoch(input);

    final str = input.toString().trim();
    if (str.isEmpty) return null;

    final isoParsed = DateTime.tryParse(str);
    if (isoParsed != null) return isoParsed.toLocal();

    try {
      if (str.contains('/')) {
        final parts = str.split('/');
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          if (d != null && m != null && y != null) {
            return DateTime(y, m, d).toLocal();
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Formats date to 'dd/MM/yyyy' or custom pattern. Returns fallback if null or invalid.
  static String formatDate(
    dynamic input, {
    String pattern = 'dd/MM/yyyy',
    String fallback = '',
  }) {
    final dt = tryParseDateTime(input);
    if (dt == null) {
      return fallback.isNotEmpty ? fallback : (input?.toString() ?? '');
    }
    try {
      return DateFormat(pattern).format(dt);
    } catch (_) {
      return fallback;
    }
  }

  /// Formats date and time to 'dd/MM/yyyy, HH:mm'.
  static String formatDateTime(
    dynamic input, {
    String pattern = 'dd/MM/yyyy, HH:mm',
    String fallback = '',
  }) {
    final dt = tryParseDateTime(input);
    if (dt == null) {
      return fallback.isNotEmpty ? fallback : (input?.toString() ?? '');
    }
    try {
      return DateFormat(pattern).format(dt);
    } catch (_) {
      return fallback;
    }
  }

  /// Formats date for backend payload ('yyyy-MM-dd').
  static String toApiDate(DateTime? date) {
    return _isoDateFormat.format(date ?? DateTime.now());
  }

  /// Formats time for backend payload ('HH:mm:ss.SSSZ').
  static String toApiTime(String? userTime) {
    if (userTime == null || userTime.trim().isEmpty) {
      return "${_isoTimeFormat.format(DateTime.now())}Z";
    }
    final clean = userTime.replaceAll(RegExp(r'[^0-9:]'), '').trim();
    final parts = clean.split(':');
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      final hh = parts[0].padLeft(2, '0');
      final mm = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1].padLeft(2, '0')
          : '00';
      return "$hh:$mm:00.000Z";
    }
    return "${_isoTimeFormat.format(DateTime.now())}Z";
  }

  /// Relative time helper in French (e.g. "À l'instant", "Il y a 5 min", "Il y a 2 j").
  static String formatRelativeTime(dynamic input) {
    final dt = tryParseDateTime(input);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 60) {
      return "À l'instant";
    }
    if (diff.inMinutes < 60) {
      return "Il y a ${diff.inMinutes} min";
    }
    if (diff.inHours < 24) {
      return "Il y a ${diff.inHours} h";
    }
    if (diff.inDays < 7) {
      return "Il y a ${diff.inDays} j";
    }
    return formatDate(dt);
  }

  /// Safe 12-hour format converter (e.g. "14:30" -> "02:30 PM").
  static String formatTo12Hour(dynamic input) {
    if (input == null) return '';
    final str = input.toString().trim();
    if (str.isEmpty) return '';

    final matches = RegExp(r'(\d+)').allMatches(str).toList();
    if (matches.length >= 2) {
      final hour = int.tryParse(matches[0].group(0) ?? '') ?? 0;
      final minute = int.tryParse(matches[1].group(0) ?? '') ?? 0;
      final period = hour >= 12 ? 'PM' : 'AM';
      var displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;
      return "${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period";
    }
    return str;
  }
}
