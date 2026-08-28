import 'dart:ui';
import 'package:binetatour/presentation/shop/widget/product_audio_item.dart';
import 'package:binetatour/presentation/shop/widget/product_video_item.dart';
import 'package:flutter/material.dart';

class ProductContent {
  final String url;
  final bool isVideo;
  final bool isImage;
  final bool isAudio;
  final bool isNetwork;

  ProductContent({
    required this.url,
    required this.isVideo,
    required this.isImage,
    required this.isAudio,
    required this.isNetwork,
  });
}

class ProductMediaView extends StatelessWidget {
  final ProductContent media;
  final int productId;
  final String? mainImage;
  final bool isMuted;
  final bool isActive;

  const ProductMediaView({
    super.key,
    required this.media,
    required this.productId,
    this.mainImage,
    required this.isMuted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return RepaintBoundary(
        child: ProductVideoItem(
          productId: productId,
          videoUrl: media.url,
          thumbnailUrl: mainImage,
          isMuted: isMuted,
          isActive: isActive,
        ),
      );
    } else if (media.isAudio) {
      return RepaintBoundary(
        child: ProductAudioItem(
          audioUrl: media.url,
          isMuted: isMuted,
          isActive: isActive,
        ),
      );
    } else {
      return InteractiveViewer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background image
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 8.0,
                    sigmaY: 8.0,
                  ),
                  child: Image.network(
                    media.url,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.35),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
              ),
            ),
            // Clear foreground image
            Center(
              child: Image.network(
                media.url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 100,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
