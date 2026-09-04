import 'package:binetatour/core/base_url/base_url.dart';

/// Centralized URL resolver that connects and standardizes video & media URLs
/// between /api/mobile/home/ and /api/mobile/products/{id}/.
///
/// Ensures both APIs always map (hls_url, media_url) to the identical URL string,
/// enabling zero-latency handoff, seamless ongoing playback, and avoiding reloads.
class MediaUrlResolver {
  const MediaUrlResolver._();

  /// Resolves any relative URL to an absolute URL with BaseUrl.
  /// Preserves Cloudflare Stream HLS manifests (/manifest/video.m3u8) for dynamic adaptive bitrate streaming.
  static String resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String clean = url.trim();
    if (!clean.startsWith('http') &&
        !clean.startsWith('file://') &&
        !clean.startsWith('/data')) {
      final base = BaseUrl.baseUrl;
      clean = clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }
    return clean;
  }

  /// Maps video URL from API fields: given media_url and hls_url,
  /// resolves them in a standardized way.
  /// Prioritizes Cloudflare Stream adaptive HLS (.m3u8) so the player can dynamically
  /// adjust video resolution and bitrate based on real-time internet speed.
  static String resolveVideoUrl({
    String? mediaUrl,
    String? hlsUrl,
    String? videoUrl,
  }) {
    // 1. If adaptive HLS URL is provided (Cloudflare Stream ABR), prioritize it
    // so the video player automatically adjusts resolution and bitrate to internet speed.
    if (hlsUrl != null && hlsUrl.trim().isNotEmpty) {
      return resolveUrl(hlsUrl.trim());
    }

    // 2. Otherwise check direct mediaUrl / videoUrl
    final rawMedia = (mediaUrl != null && mediaUrl.trim().isNotEmpty)
        ? mediaUrl.trim()
        : (videoUrl != null && videoUrl.trim().isNotEmpty
              ? videoUrl.trim()
              : null);

    if (rawMedia != null && rawMedia.isNotEmpty) {
      // If direct media is from Cloudflare Stream with /downloads/default.mp4, convert to
      // /manifest/video.m3u8 so that adaptive bitrate streaming is enabled.
      if (rawMedia.contains('cloudflarestream.com') &&
          rawMedia.contains('/downloads/default.mp4')) {
        return resolveUrl(
          rawMedia.replaceAll('/downloads/default.mp4', '/manifest/video.m3u8'),
        );
      }
      return resolveUrl(rawMedia);
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

  static final RegExp _cloudflareRegExp = RegExp(
    r'(https?://[^/]+)/([a-fA-F0-9]{32})',
  );
  static final RegExp _cloudflareFallbackRegExp = RegExp(
    r'(?:cloudflarestream\.com|videodelivery\.net)/([a-zA-Z0-9]+)',
  );

  /// Extracts a Cloudflare thumbnail URL if the video is hosted on Cloudflare Stream
  static String extractThumbnailFromVideoUrl(String? videoUrl) {
    if (videoUrl == null || videoUrl.trim().isEmpty) return '';
    final clean = videoUrl.trim();
    if (clean.contains('cloudflarestream.com') ||
        clean.contains('videodelivery.net')) {
      final match = _cloudflareRegExp.firstMatch(clean);
      if (match != null && match.groupCount >= 2) {
        final host = match.group(1);
        final id = match.group(2);
        return '$host/$id/thumbnails/thumbnail.jpg?width=640';
      }
      final fallbackMatch = _cloudflareFallbackRegExp.firstMatch(clean);
      if (fallbackMatch != null && fallbackMatch.groupCount >= 1) {
        final id = fallbackMatch.group(1);
        return 'https://customer-xe2czubswwdkm567.cloudflarestream.com/$id/thumbnails/thumbnail.jpg?width=640';
      }
    }
    return '';
  }
}
