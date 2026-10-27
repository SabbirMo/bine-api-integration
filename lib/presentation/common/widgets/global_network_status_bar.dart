import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:binetatour/core/network/network_status_service.dart';

/// Facebook-style floating network banner that appears at the top of the screen
/// when the user has no internet connection, an extremely slow network,
/// or when connectivity is restored.
class GlobalNetworkStatusBar extends StatefulWidget {
  const GlobalNetworkStatusBar({super.key});

  @override
  State<GlobalNetworkStatusBar> createState() => _GlobalNetworkStatusBarState();
}

class _GlobalNetworkStatusBarState extends State<GlobalNetworkStatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NetworkStatusService.instance,
      builder: (context, _) {
        final service = NetworkStatusService.instance;
        final isVisible = service.shouldShowBanner;

        final isEn =
            Localizations.maybeLocaleOf(context)?.languageCode.toLowerCase() ==
            'en';

        Color backgroundColor;
        IconData icon;
        String title;
        String subtitle;

        if (service.isOffline) {
          backgroundColor = const Color(0xFFD32F2F); // Rich red
          icon = Icons.wifi_off_rounded;
          title = isEn ? 'No Internet Connection' : 'Aucune connexion Internet';
          subtitle = isEn
              ? 'Check Wi-Fi or mobile data'
              : 'Vérifiez vos données mobiles ou Wi-Fi';
        } else if (service.isSlow) {
          backgroundColor = const Color(0xFFFF8A00); // Brand amber
          icon = Icons.speed_rounded;
          title = isEn
              ? 'Slow Internet Connection'
              : 'Connexion Internet lente';
          subtitle = isEn
              ? 'Loading may take longer'
              : 'Le chargement peut prendre du temps';
        } else {
          // Restored
          backgroundColor = const Color(0xFF2E7D32); // Emerald green
          icon = Icons.check_circle_rounded;
          title = isEn ? 'Back Online' : 'Connexion rétablie';
          subtitle = isEn
              ? 'Connection is fast and stable'
              : 'Vous êtes de nouveau en ligne';
        }

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 380),
              curve: isVisible ? Curves.easeOutBack : Curves.easeInCubic,
              offset: isVisible ? Offset.zero : const Offset(0, -1.4),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: isVisible ? 1.0 : 0.0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 6.0,
                    ),
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        // Swipe up to dismiss temporarily
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity! < -100) {
                          HapticFeedback.lightImpact();
                          service.dismissTemporarily();
                        }
                      },
                      onTap: () {
                        if (!service.showRestoredBanner) {
                          HapticFeedback.selectionClick();
                          service.checkConnectivity();
                        }
                      },
                      child: Material(
                        color: Colors.transparent,
                        elevation: 6,
                        shadowColor: backgroundColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 9.0,
                          ),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: backgroundColor.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Left Icon (with subtle pulse animation on offline)
                              service.isOffline
                                  ? ScaleTransition(
                                      scale: _pulseAnimation,
                                      child: Icon(
                                        icon,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : Icon(icon, color: Colors.white, size: 20),
                              const SizedBox(width: 10),

                              // Text Column
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Right Action: Spinner, Refresh button, or Dismiss
                              if (service.isChecking)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              else if (!service.showRestoredBanner)
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    service.checkConnectivity();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
