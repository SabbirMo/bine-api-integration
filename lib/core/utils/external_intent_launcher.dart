import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result status for external launch operations
enum LaunchResultStatus {
  success,
  invalidUrl,
  appNotInstalled,
  failed,
}

class ExternalIntentLauncher {
  ExternalIntentLauncher._();

  /// Clean phone numbers by removing all non-numeric characters.
  static String sanitizePhoneForWhatsApp(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Clean phone numbers for tel: intents
  static String sanitizePhoneForCall(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// Safe generic URL launcher with fallback
  static Future<bool> openUrl(
    String rawUrl, {
    LaunchMode mode = LaunchMode.externalApplication,
    BuildContext? context,
    String? errorMessage,
  }) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (!uri.hasScheme && !uri.isAbsolute)) {
      debugPrint('[ExternalIntentLauncher] Invalid URL: $rawUrl');
      _showErrorSnackBar(context, errorMessage ?? "Lien invalide.");
      return false;
    }

    try {
      final launched = await launchUrl(uri, mode: mode);
      if (!launched && mode != LaunchMode.platformDefault) {
        final fallbackLaunched =
            await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched) {
          _showErrorSnackBar(
              context, errorMessage ?? "Impossible d'ouvrir le lien.");
        }
        return fallbackLaunched;
      }
      return launched;
    } catch (e) {
      debugPrint('[ExternalIntentLauncher] Error launching $rawUrl: $e');
      _showErrorSnackBar(
          context, errorMessage ?? "Impossible d'ouvrir le lien.");
      return false;
    }
  }

  /// Safe WhatsApp Launcher with automatic fallback to Web (wa.me)
  static Future<LaunchResultStatus> openWhatsApp({
    required String phone,
    String? message,
    BuildContext? context,
  }) async {
    final cleanPhone = sanitizePhoneForWhatsApp(phone);
    final text = message?.trim() ?? '';

    // 1. WhatsApp Native Scheme
    final Uri appUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {
        if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
        if (text.isNotEmpty) 'text': text,
      },
    );

    // 2. WhatsApp Web URL
    final Uri webUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: cleanPhone.isNotEmpty ? '/$cleanPhone' : '',
      queryParameters: text.isNotEmpty ? {'text': text} : null,
    );

    bool launched = false;

    // Step 1: Try Native App via externalNonBrowserApplication
    try {
      launched = await launchUrl(
        appUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      launched = false;
    }

    // Step 2: Try Native App via externalApplication
    if (!launched) {
      try {
        launched = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    // Step 3: Fallback to Web in External Browser
    if (!launched) {
      try {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    // Step 4: Final fallback with platformDefault
    if (!launched) {
      try {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      _showErrorSnackBar(
        context,
        "WhatsApp n'est pas disponible et impossible d'ouvrir le navigateur.",
      );
      return LaunchResultStatus.failed;
    }

    return LaunchResultStatus.success;
  }

  /// Safe Phone Call (tel:)
  static Future<bool> makePhoneCall(
    String phoneNumber, {
    BuildContext? context,
  }) async {
    final sanitized = sanitizePhoneForCall(phoneNumber);
    final Uri uri = Uri(scheme: 'tel', path: sanitized);

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showErrorSnackBar(context, "Impossible de composer le numéro.");
      }
      return launched;
    } catch (e) {
      debugPrint('[ExternalIntentLauncher] Error calling $phoneNumber: $e');
      _showErrorSnackBar(context, "Impossible de composer le numéro.");
      return false;
    }
  }

  /// Safe Payment DeepLink (Wave, OM, etc.) with cascading fallbacks
  static Future<bool> launchPaymentDeepLink({
    required String deepLinkUrl,
    BuildContext? context,
    String? fallbackWebUrl,
  }) async {
    final uri = Uri.tryParse(deepLinkUrl.trim());
    if (uri == null) {
      _showErrorSnackBar(context, "Lien de paiement invalide.");
      return false;
    }

    bool launched = false;

    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && fallbackWebUrl != null && fallbackWebUrl.isNotEmpty) {
      final webUri = Uri.tryParse(fallbackWebUrl.trim());
      if (webUri != null) {
        try {
          launched =
              await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } catch (_) {
          launched = false;
        }
      }
    }

    if (!launched) {
      _showErrorSnackBar(
        context,
        "Impossible d'ouvrir l'application ou la page de paiement.",
      );
    }

    return launched;
  }

  static void _showErrorSnackBar(BuildContext? context, String message) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
