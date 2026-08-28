import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Media Counter Badge (e.g. 1 / 6)
              if (mediaCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${currentMediaIndex + 1} / $mediaCount",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Spacer(),
              // Mute Button (only for Videos & Audios)
              if (isVideoOrAudio)
                _buildCircleIcon(
                  icon: isMuted ? Icons.volume_off : Icons.volume_up,
                  onTap: onMuteToggle,
                ),
              const SizedBox(width: 10),
              // Close Button
              _buildCircleIcon(
                icon: Icons.close,
                onTap: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
