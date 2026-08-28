import 'package:flutter/material.dart';
import 'package:binetatour/core/video/smart_video_controller.dart';
import 'package:binetatour/presentation/common/widgets/video_player_screen.dart';

/// Example screen demonstrating how to use [SmartVideoController] and [VideoPlayerScreen]
/// with Cloudflare Stream HLS master manifests.
class VideoPlayerExampleScreen extends StatefulWidget {
  const VideoPlayerExampleScreen({super.key});

  @override
  State<VideoPlayerExampleScreen> createState() => _VideoPlayerExampleScreenState();
}

class _VideoPlayerExampleScreenState extends State<VideoPlayerExampleScreen> {
  // Example Cloudflare Stream HLS manifest URL
  static const String demoCloudflareStreamUrl =
      'https://customer-m033z5x00ks6xegi.cloudflarestream.com/b247879685a1a09633e214d02636a28d/manifest/video.m3u8';

  SmartVideoController? _inlineController;

  @override
  void initState() {
    super.initState();
    _inlineController = SmartVideoController(
      originalUrl: demoCloudflareStreamUrl,
      config: const SmartVideoConfig(
        autoPlay: false,
        loop: true,
        cacheSecs: 45,
        demuxerReadaheadSecs: 30,
      ),
    );
  }

  @override
  void dispose() {
    _inlineController?.dispose();
    super.dispose();
  }

  void _openFullScreenPlayer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const VideoPlayerScreen(
          videoUrl: demoCloudflareStreamUrl,
          title: 'Démonstration Cloudflare Stream HLS',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloudflare Stream HLS Player'),
        backgroundColor: const Color(0xFFFF8A00),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lecteur Intégré (Adaptive Bitrate)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Qualité adaptative automatique avec libmpv, reprise automatique sur perte de réseau et mise en cache optimisée.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Embedded Player Widget
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _inlineController != null
                    ? SmartVideoPlayerWidget(
                        controller: _inlineController!,
                        title: 'Aperçu HLS',
                        onFullscreenToggle: () => _openFullScreenPlayer(context),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: 24),

            // Button to open Full-screen Player
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.fullscreen_rounded),
                label: const Text(
                  'Ouvrir en plein écran',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openFullScreenPlayer(context),
              ),
            ),

            const SizedBox(height: 24),

            // Features Checklist Card
            Card(
              elevation: 0,
              color: const Color(0xFFF7F7F7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fonctionnalités Clés :',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    _FeatureItem(text: 'HLS Adaptive Bitrate (hls-bitrate=auto)'),
                    _FeatureItem(text: 'Mise en cache libmpv (cache=yes, cache-secs=45s)'),
                    _FeatureItem(text: 'Capture de trame vidéo en direct (player.screenshot)'),
                    _FeatureItem(text: 'Résolution 100% automatique selon le réseau (240p - 1080p)'),
                    _FeatureItem(text: 'Contrôles tactiles (double tap -10s/+10s, vitesse)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;
  const _FeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFFFF8A00), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
