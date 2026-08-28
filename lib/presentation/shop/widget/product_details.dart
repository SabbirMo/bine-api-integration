// ignore_for_file: must_be_immutable

import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/widgets/smooth_reels_scroll_physics.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/shop/widget/product_details/product_media_gallery.dart';
import 'package:flutter/material.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int initialProductIndex;
  final List<ProductModel> allProducts;

  const ProductDetailsScreen({
    super.key,
    required this.initialProductIndex,
    required this.allProducts,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with WidgetsBindingObserver {
  late PageController _verticalController;
  late int _currentPageIndex;
  bool isExpanded = false;
  bool _isMuted = false;
  bool _isScreenPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPageIndex = widget.initialProductIndex;
    _verticalController =
        PageController(initialPage: widget.initialProductIndex);
    _precacheAround(widget.initialProductIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) setState(() => _isScreenPaused = true);
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _isScreenPaused = false);
    }
  }

  String _resolveUrl(String? url) {
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

  void _precacheAround(int index) {
    if (!mounted) return;
    final indices = [index + 1, index + 2, index - 1];
    for (final nextIndex in indices) {
      if (nextIndex >= 0 && nextIndex < widget.allProducts.length) {
        final p = widget.allProducts[nextIndex];
        final vUrl = p.effectiveVideoUrl;
        if (vUrl.isNotEmpty) {
          final clean = _resolveUrl(vUrl);
          if (clean.isNotEmpty) {
            VideoCacheManager.instance.preCacheVideo(clean);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _verticalController,
          scrollDirection: Axis.vertical, // Swipe up for next product
          physics: const SmoothReelsScrollPhysics(),
          itemCount: widget.allProducts.length,
          onPageChanged: (index) {
            setState(() {
              _currentPageIndex = index;
            });
            _precacheAround(index);
          },
          itemBuilder: (context, index) {
            final product = widget.allProducts[index];
            final isActive = index == _currentPageIndex && !_isScreenPaused;
            return RepaintBoundary(
              child: ProductMediaGallery(
                product: product,
                isActive: isActive,
                isMuted: _isMuted,
                onMuteToggle: () => setState(() => _isMuted = !_isMuted),
                isExpanded: isExpanded,
                onPause: () {
                  if (mounted) setState(() => _isScreenPaused = true);
                },
                onResume: () {
                  if (mounted) setState(() => _isScreenPaused = false);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
