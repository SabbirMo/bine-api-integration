import 'package:flutter/foundation.dart';
import 'package:binetatour/core/network/network_status_service.dart';

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
class NetworkQualityEstimator extends ChangeNotifier {
  static final NetworkQualityEstimator _instance =
      NetworkQualityEstimator._internal();
  static NetworkQualityEstimator get instance => _instance;

  NetworkQualityEstimator._internal();

  NetworkTier _currentTier = NetworkTier.low;
  NetworkTier get currentTier => _currentTier;

  double _estimatedBandwidthBps =
      500000; // start conservative at 240p (~500 Kbps)
  int _consecutiveFastDownloads = 0;
  DateTime? _lastStallTime;

  /// Always returns 'min' (240p) to guarantee zero-latency 0ms startup for any new video,
  /// matching Instagram Reels / TikTok behavior.
  String getInitialMpvHlsBitrate() => 'min';

  /// Records download measurement from segment/manifest pre-fetching.
  void recordMeasurement({required int bytes, required int durationMs}) {
    if (bytes <= 0 || durationMs <= 0) return;

    final bps = (bytes * 8 * 1000) / durationMs;
    // Exponential moving average (weight 60% previous, 40% current)
    _estimatedBandwidthBps = (_estimatedBandwidthBps * 0.6) + (bps * 0.4);

    final previousTier = _currentTier;
    if (_estimatedBandwidthBps > 2800000 && durationMs < 800) {
      _consecutiveFastDownloads++;
      if (_consecutiveFastDownloads >= 3) {
        _currentTier = NetworkTier.ultra;
      } else {
        _currentTier = NetworkTier.high;
      }
    } else if (_estimatedBandwidthBps > 1400000 && durationMs < 1200) {
      _consecutiveFastDownloads++;
      if (_consecutiveFastDownloads >= 2) {
        _currentTier = NetworkTier.high;
      } else {
        _currentTier = NetworkTier.medium;
      }
    } else if (_estimatedBandwidthBps > 700000 && durationMs < 1800) {
      _consecutiveFastDownloads++;
      _currentTier = NetworkTier.medium;
    } else {
      _consecutiveFastDownloads = 0;
      _currentTier = NetworkTier.low;
    }

    if (_estimatedBandwidthBps < 350000 && durationMs > 2500) {
      NetworkStatusService.instance.reportSlow(
        reason:
            'Débit vidéo faible (${(_estimatedBandwidthBps / 1000).toStringAsFixed(0)} Kbps)',
      );
    }

    if (previousTier != _currentTier) {
      debugPrint(
        '⚡️ [NetworkQualityEstimator] ABR tier changed: ${previousTier.name} -> ${_currentTier.name} (${(_estimatedBandwidthBps / 1000).toStringAsFixed(0)} Kbps)',
      );
      notifyListeners();
    }
  }

  /// Called when player experiences buffering or stall, immediately downgrading to low (240p).
  /// Debounced by 2.5 seconds to prevent runaway rapid spam logging in loop watchdogs.
  void recordPlaybackStall() {
    final now = DateTime.now();
    if (_lastStallTime != null &&
        now.difference(_lastStallTime!) < const Duration(milliseconds: 2500)) {
      return;
    }
    _lastStallTime = now;

    final wasHigherTier = _currentTier != NetworkTier.low;
    _consecutiveFastDownloads = 0;
    _estimatedBandwidthBps = 400000;
    _currentTier = NetworkTier.low;

    debugPrint(
      '⚡️ [NetworkQualityEstimator] Playback stall detected: downgraded ABR tier to LOW (240p)',
    );

    // Notify global network monitor that playback stalled due to network bottleneck
    NetworkStatusService.instance.reportSlow(reason: 'Buffering vidéo détecté');

    if (wasHigherTier) {
      notifyListeners();
    }
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
