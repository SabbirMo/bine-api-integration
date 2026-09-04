import 'package:flutter/cupertino.dart';

class ProductDetailsTopOverlay extends StatelessWidget {
  final int currentMediaIndex;
  final int mediaCount;
  final bool isVideoOrAudio;
  final bool isMuted;
  final VoidCallback onMuteToggle;
  final VoidCallback onClose;

  const ProductDetailsTopOverlay({
    super.key,
    required this.currentMediaIndex,
    required this.mediaCount,
    required this.isVideoOrAudio,
    required this.isMuted,
    required this.onMuteToggle,
    required this.onClose,
  });

  Widget _buildCircleIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(36),
      pressedOpacity: 0.65,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0x33FFFFFF), // Translucent Cupertino glass feel
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: CupertinoColors.white, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Media Counter Badge (e.g. 1 / 6)
              if (mediaCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x66000000), // Cupertino blur background
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "${currentMediaIndex + 1} / $mediaCount",
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const Spacer(),
              // Mute Button (only for Videos & Audios)
              if (isVideoOrAudio)
                _buildCircleIcon(
                  icon: isMuted
                      ? CupertinoIcons.speaker_slash_fill
                      : CupertinoIcons.speaker_2_fill,
                  onTap: onMuteToggle,
                ),
              const SizedBox(width: 8),
              // Close Button
              _buildCircleIcon(icon: CupertinoIcons.xmark, onTap: onClose),
            ],
          ),
        ),
      ),
    );
  }
}
