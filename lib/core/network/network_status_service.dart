import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network connection states for the application.
enum NetworkStatus {
  /// Fast, stable network connection
  online,

  /// Slow or unstable network (high latency, video stalls, cellular packet drop)
  slow,

  /// Completely disconnected (no Wi-Fi, no mobile data, or unreachable host)
  offline,
}

/// Global Network Status Service that monitors real connectivity, API latency,
/// and video playback buffering events.
class NetworkStatusService extends ChangeNotifier {
  static final NetworkStatusService _instance =
      NetworkStatusService._internal();
  static NetworkStatusService get instance => _instance;

  NetworkStatusService._internal();

  NetworkStatus _status = NetworkStatus.online;
  NetworkStatus get status => _status;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  bool _wasDisconnected = false;
  bool _showRestoredBanner = false;
  bool get showRestoredBanner => _showRestoredBanner;

  /// User manually swiped to hide the banner temporarily
  bool _isTemporarilyDismissed = false;
  bool get isTemporarilyDismissed => _isTemporarilyDismissed;

  bool get isOffline => _status == NetworkStatus.offline;
  bool get isSlow => _status == NetworkStatus.slow;
  bool get isOnline => _status == NetworkStatus.online;

  /// Whether the floating banner should currently be visible
  bool get shouldShowBanner =>
      (!_isTemporarilyDismissed && (isOffline || isSlow)) || _showRestoredBanner;

  Timer? _periodicTimer;
  Timer? _restoredDismissTimer;
  Timer? _slowRecoveryTimer;
  DateTime? _lastSlowTime;
  bool _initialized = false;

  /// Initializes the background periodic network monitoring
  void init() {
    if (_initialized) return;
    _initialized = true;

    // Initial check on startup
    checkConnectivity();

    // Background periodic health-check every 15 seconds
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkConnectivity();
    });
  }

  /// Manually triggers a real DNS/socket probe to verify connectivity.
  Future<void> checkConnectivity() async {
    if (_isChecking) return;
    _isChecking = true;
    notifyListeners();

    try {
      final stopwatch = Stopwatch()..start();
      // Fast DNS query against production domain
      final result = await InternetAddress.lookup('api.bawane.com')
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (elapsedMs > 3500) {
          reportSlow(reason: 'Latence DNS élevée (${elapsedMs}ms)');
        } else {
          // If we were in a slow state, ensure a minimum cooldown before clearing
          if (_status == NetworkStatus.slow) {
            final timeSinceSlow = _lastSlowTime != null
                ? DateTime.now().difference(_lastSlowTime!)
                : const Duration(seconds: 10);
            if (timeSinceSlow.inSeconds >= 4) {
              reportOnline();
            }
          } else {
            reportOnline();
          }
        }
      } else {
        reportOffline(reason: 'Aucune adresse IP résolue');
      }
    } on TimeoutException {
      reportOffline(reason: 'Délai d\'attente dépassé (Timeout)');
    } on SocketException catch (e) {
      reportOffline(reason: 'Réseau inaccessible (${e.message})');
    } catch (e) {
      reportOffline(reason: 'Erreur réseau: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Called when an offline event occurs (socket failure, connection timeout, no data).
  void reportOffline({String? reason}) {
    _slowRecoveryTimer?.cancel();

    if (_status == NetworkStatus.offline) return;

    _status = NetworkStatus.offline;
    _wasDisconnected = true;
    _showRestoredBanner = false;
    _isTemporarilyDismissed = false; // Reset dismiss on new state
    _restoredDismissTimer?.cancel();

    if (kDebugMode) {
      debugPrint('🔴 [NetworkStatus] Device is OFFLINE: ${reason ?? "Network drop"}');
    }
    notifyListeners();
  }

  /// Called when slow network is observed (high API latency, video stalls, retry).
  void reportSlow({String? reason}) {
    // If currently offline, offline takes precedence
    if (_status == NetworkStatus.offline) return;

    _lastSlowTime = DateTime.now();

    final wasOnline = _status == NetworkStatus.online;
    _status = NetworkStatus.slow;
    _wasDisconnected = true;
    _showRestoredBanner = false;
    _isTemporarilyDismissed = false; // Reset dismiss on new state
    _restoredDismissTimer?.cancel();

    if (wasOnline && kDebugMode) {
      debugPrint('🟠 [NetworkStatus] Connection is SLOW: ${reason ?? "Latency/Buffering"}');
    }
    notifyListeners();

    // Auto-recovery check after 7 seconds if no further stalls occur
    _slowRecoveryTimer?.cancel();
    _slowRecoveryTimer = Timer(const Duration(seconds: 7), () {
      if (_status == NetworkStatus.slow) {
        checkConnectivity();
      }
    });
  }

  /// Called when operations succeed smoothly (fast API response, successful probe).
  void reportOnline() {
    if (_status == NetworkStatus.online && !_showRestoredBanner) {
      return;
    }

    final hadIssue =
        _status == NetworkStatus.offline || _status == NetworkStatus.slow;
    _status = NetworkStatus.online;
    _slowRecoveryTimer?.cancel();
    _isTemporarilyDismissed = false;

    if (hadIssue && _wasDisconnected) {
      _showRestoredBanner = true;
      if (kDebugMode) {
        debugPrint('🟢 [NetworkStatus] Connection RESTORED (Online)');
      }
      notifyListeners();

      _restoredDismissTimer?.cancel();
      _restoredDismissTimer = Timer(const Duration(milliseconds: 2800), () {
        _showRestoredBanner = false;
        _wasDisconnected = false;
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  /// User dismissed the banner by swiping up
  void dismissTemporarily() {
    _isTemporarilyDismissed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _restoredDismissTimer?.cancel();
    _slowRecoveryTimer?.cancel();
    super.dispose();
  }
}
