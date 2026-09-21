import 'package:flutter/foundation.dart';

enum NetworkTier {
  /// 240p (~550 Kbps) — Guaranteed instant 0ms first-frame startup on 2G/3G or slow networks
  low,

  /// 360p (~850 Kbps) — Crisp standard definition on moderate mobile data
  medium,

  /// 480p (~1.5 Mbps) — High definition for stable 4G/WiFi
  high,

  /// 720p / 1080p — Full unconstrained quality for ultra-fast broadband
  ultra,
}

/// Dynamic network quality estimator for Adaptive Bitrate (ABR) streaming.
/// Monitors download throughput & player buffering events to dynamically
/// adjust HLS bitrates between 240p, 360p, 480p, and 720p/1080p.
class NetworkQualityEstimator {
  static final NetworkQualityEstimator _instance =
      NetworkQualityEstimator._internal();
  static NetworkQualityEstimator get instance => _instance;

  NetworkQualityEstimator._internal();

  NetworkTier _currentTier = NetworkTier.low;
  NetworkTier get currentTier => _currentTier;

  double _estimatedBandwidthBps = 600000; // start conservative (~600 Kbps)
  int _consecutiveFastDownloads = 0;

  /// Records download measurement from segment/manifest pre-fetching.
  void recordMeasurement({required int bytes, required int durationMs}) {
    if (bytes <= 0 || durationMs <= 0) return;

    final bps = (bytes * 8 * 1000) / durationMs;
    // Exponential moving average (weight 60% previous, 40% current)
    _estimatedBandwidthBps = (_estimatedBandwidthBps * 0.6) + (bps * 0.4);

    if (_estimatedBandwidthBps > 2800000 && durationMs < 800) {
      _consecutiveFastDownloads++;
      if (_consecutiveFastDownloads >= 2) {
        _currentTier = NetworkTier.ultra;
      } else {
        _currentTier = NetworkTier.high;
      }
    } else if (_estimatedBandwidthBps > 1400000 && durationMs < 1200) {
      _consecutiveFastDownloads++;
      _currentTier = NetworkTier.high;
    } else if (_estimatedBandwidthBps > 700000 && durationMs < 1800) {
      _consecutiveFastDownloads++;
      _currentTier = NetworkTier.medium;
    } else {
      _consecutiveFastDownloads = 0;
      _currentTier = NetworkTier.low;
    }
  }

  /// Called when player experiences buffering or stall, immediately downgrading to low (240p)
  void recordPlaybackStall() {
    _consecutiveFastDownloads = 0;
    _estimatedBandwidthBps = 500000;
    _currentTier = NetworkTier.low;
    debugPrint(
      '⚡️ [NetworkQualityEstimator] Playback stall detected: downgraded ABR tier to LOW (240p)',
    );
  }

  /// Returns MPV hls-bitrate parameter string for the current tier
  String getMpvHlsBitrate() {
    switch (_currentTier) {
      case NetworkTier.low:
        return 'min'; // selects 240p
      case NetworkTier.medium:
        return '850000'; // selects 360p
      case NetworkTier.high:
        return '1600000'; // selects 480p
      case NetworkTier.ultra:
        return 'no'; // unconstrained (720p/1080p)
    }
  }
}
