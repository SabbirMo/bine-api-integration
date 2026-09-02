import 'package:binetatour/core/base_url/base_url.dart';

/// Centralized URL resolver that connects and standardizes video & media URLs
/// between /api/mobile/home/ and /api/mobile/products/{id}/.
///
/// Ensures both APIs always map (hls_url, media_url) to the identical URL string,
/// enabling zero-latency handoff, seamless ongoing playback, and avoiding reloads.
class MediaUrlResolver {
  const MediaUrlResolver._();

  /// Resolves any relative URL to an absolute URL with BaseUrl
  /// and normalizes Cloudflare Stream / HLS to direct MP4 for 0ms demuxing and disk caching.
  static String resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String clean = url.trim();
    if (!clean.startsWith('http') &&
        !clean.startsWith('file://') &&
        !clean.startsWith('/data')) {
      final base = BaseUrl.baseUrl;
      clean = clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }
    // Normalize Cloudflare Stream HLS to direct MP4 for instant demuxing, disk caching, and seamless matching
    if (clean.contains('cloudflarestream.com') &&
        clean.contains('/manifest/video.m3u8')) {
      clean = clean.replaceAll('/manifest/video.m3u8', '/downloads/default.mp4');
    }
    return clean;
  }

  /// Maps video URL from API fields: given media_url and hls_url,
  /// resolves them in a standardized, connected way across both APIs.
  static String resolveVideoUrl({
    String? mediaUrl,
    String? hlsUrl,
    String? videoUrl,
  }) {
    // 1. Prefer direct mediaUrl / videoUrl if valid and non-empty
    final rawMedia = (mediaUrl != null && mediaUrl.trim().isNotEmpty)
        ? mediaUrl.trim()
        : (videoUrl != null && videoUrl.trim().isNotEmpty ? videoUrl.trim() : null);

    if (rawMedia != null && rawMedia.isNotEmpty) {
      return resolveUrl(rawMedia);
    }

    // 2. Fall back to hlsUrl (normalized to MP4 if Cloudflare)
    if (hlsUrl != null && hlsUrl.trim().isNotEmpty) {
      return resolveUrl(hlsUrl.trim());
    }

    return '';
  }

  /// Checks if a given URL points to a video stream or file.
  static bool isVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase().split('?').first.split('#').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.m3u8') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.flv') ||
        clean.endsWith('.3gp') ||
        clean.contains('.mp4') ||
        clean.contains('.m3u8');
  }
}
