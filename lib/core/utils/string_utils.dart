class AppStringUtils {
  AppStringUtils._();

  /// Cleans and sanitizes phone numbers for WhatsApp/Tel links.
  static String cleanPhoneForWhatsApp(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return '';
    return rawPhone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Builds a safe WhatsApp URI.
  static Uri? buildWhatsAppUri({
    required String? rawPhone,
    required String message,
    bool useAppScheme = false,
  }) {
    final cleanPhone = cleanPhoneForWhatsApp(rawPhone);
    final encodedMsg = Uri.encodeComponent(message);

    if (useAppScheme) {
      return Uri.tryParse(
        cleanPhone.isNotEmpty
            ? "whatsapp://send?phone=$cleanPhone&text=$encodedMsg"
            : "whatsapp://send?text=$encodedMsg",
      );
    }
    return Uri.tryParse(
      cleanPhone.isNotEmpty
          ? "https://wa.me/$cleanPhone?text=$encodedMsg"
          : "https://wa.me?text=$encodedMsg",
    );
  }

  /// Safely checks if a given URL is a video URL.
  static bool isVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase().split('?').first.split('#').first;
    const extensions = [
      '.mp4',
      '.mov',
      '.m3u8',
      '.webm',
      '.avi',
      '.mkv',
      '.flv',
      '.3gp'
    ];
    return extensions.any((ext) => clean.endsWith(ext)) ||
        clean.contains('.mp4') ||
        clean.contains('.m3u8');
  }

  /// Safe URI parse wrapper.
  static Uri? safeUri(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return Uri.tryParse(url.trim());
  }
}
