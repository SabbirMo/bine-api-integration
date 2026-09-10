import 'dart:async';
import 'package:binetatour/core/utils/media_url_resolver.dart';
import 'package:binetatour/core/widgets/smooth_reels_scroll_physics.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/core/video/reels_video_controller_pool.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/shop/widget/product_details/product_media_gallery.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int initialProductIndex;
  final List<ProductModel> allProducts;
  final Duration? initialPosition;

  const ProductDetailsScreen({
    super.key,
    required this.initialProductIndex,
    required this.allProducts,
    this.initialPosition,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with WidgetsBindingObserver {
  late PageController _verticalController;
  late ValueNotifier<int> _currentPageNotifier;
  bool isExpanded = false;
  bool _isMuted = false;
  bool _isScreenPaused = false;
  Timer? _precacheTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPageNotifier = ValueNotifier<int>(widget.initialProductIndex);
    _verticalController = PageController(
      initialPage: widget.initialProductIndex,
    );
    ReelsVideoControllerPool.instance.init();

    // Immediately activate first video and pre-warm surrounding videos for 0ms startup
    if (widget.allProducts.isNotEmpty &&
        widget.initialProductIndex >= 0 &&
        widget.initialProductIndex < widget.allProducts.length) {
      final initialProd = widget.allProducts[widget.initialProductIndex];
      final vUrl = initialProd.effectiveVideoUrl;
      if (vUrl.isNotEmpty) {
        final clean = _resolveVideoUrl(vUrl);
        ReelsVideoControllerPool.instance.activateVideo(
          itemIndex: widget.initialProductIndex,
          url: clean,
          nextUrls: _getUpcomingVideoUrls(widget.initialProductIndex),
          prevUrl: _getPreviousVideoUrl(widget.initialProductIndex),
          secondPrevUrl: _getSecondPreviousVideoUrl(widget.initialProductIndex),
          initialPosition: widget.initialPosition,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _schedulePrecacheAround(widget.initialProductIndex);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) setState(() => _isScreenPaused = true);
      ReelsVideoControllerPool.instance.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (isCurrentRoute && !isExpanded) {
        if (mounted) setState(() => _isScreenPaused = false);
        ReelsVideoControllerPool.instance.resume();
      }
    }
  }

  /// Resolves and normalizes a video URL using the central MediaUrlResolver.
  String _resolveVideoUrl(String? url) => MediaUrlResolver.resolveUrl(url);

  String _resolveUrl(String? url) => MediaUrlResolver.resolveUrl(url);

  List<String> _getUpcomingVideoUrls(int index) {
    final List<String> urls = [];
    for (
      int nextIdx = index + 1;
      nextIdx < widget.allProducts.length && urls.length < 2;
      nextIdx++
    ) {
      final p = widget.allProducts[nextIdx];
      final v = p.effectiveVideoUrl;
      if (v.isNotEmpty) {
        final resolved = _resolveVideoUrl(v);
        if (resolved.isNotEmpty && !urls.contains(resolved)) {
          urls.add(resolved);
        }
      }
    }
    return urls;
  }

  String? _getPreviousVideoUrl(int index) {
    for (int prevIdx = index - 1; prevIdx >= 0; prevIdx--) {
      final p = widget.allProducts[prevIdx];
      final v = p.effectiveVideoUrl;
      if (v.isNotEmpty) {
        final resolved = _resolveVideoUrl(v);
        if (resolved.isNotEmpty) return resolved;
      }
    }
    return null;
  }

  String? _getSecondPreviousVideoUrl(int index) {
    int count = 0;
    for (int prevIdx = index - 1; prevIdx >= 0; prevIdx--) {
      final p = widget.allProducts[prevIdx];
      final v = p.effectiveVideoUrl;
      if (v.isNotEmpty) {
        count++;
        if (count == 2) {
          final resolved = _resolveVideoUrl(v);
          if (resolved.isNotEmpty) return resolved;
        }
      }
    }
    return null;
  }

  void _precacheAround(int index) {
    if (!mounted) return;
    final total = widget.allProducts.length;
    final lastIdx = total - 1;
    // Priority: Immediate Next, Immediate Previous, Second Next, Second Previous, Third Next
    // Always include the last product video so reaching the end of the feed is guaranteed instantaneous!
    final indices = <int>[
      index + 1,
      index - 1,
      index + 2,
      index - 2,
      index + 3,
    ];
    if (lastIdx > 0 && !indices.contains(lastIdx)) {
      indices.add(lastIdx);
    }
    final List<String> priorityVideos = [];

    for (final targetIndex in indices) {
      if (targetIndex >= 0 && targetIndex < total) {
        final p = widget.allProducts[targetIndex];

        // 1. Pre-fetch detailed product JSON & variants in background
        context.read<ProductProvider>().prefetchProductDetails(p.id);

        // 2. Collect video URLs in priority order
        final vUrl = p.effectiveVideoUrl;
        if (vUrl.isNotEmpty) {
          final clean = _resolveUrl(vUrl);
          if (clean.isNotEmpty && !priorityVideos.contains(clean)) {
            priorityVideos.add(clean);
          }
        }

        // 3. Precache thumbnail image into Flutter memory cache
        final tUrl = p.effectiveThumbnailUrl;
        if (tUrl.isNotEmpty) {
          final resolvedThumb = _resolveUrl(tUrl);
          if (resolvedThumb.isNotEmpty && resolvedThumb.startsWith('http')) {
            precacheImage(
              NetworkImage(resolvedThumb),
              context,
              onError: (_, _) {},
            ).catchError((_) {});
          }
        }
      }
    }

    // 4. Batch-enqueue priority downloads (Only the immediate next video to preserve 100% bandwidth for active video)
    final nextIdx = index + 1;
    if (nextIdx < total) {
      final p = widget.allProducts[nextIdx];
      final vUrl = p.effectiveVideoUrl;
      if (vUrl.isNotEmpty) {
        final clean = _resolveUrl(vUrl);
        if (clean.isNotEmpty) {
          VideoCacheManager.instance.preCachePriority(clean);
        }
      }
    }
  }

  void _schedulePrecacheAround(int index) {
    _precacheTimer?.cancel();
    // Allow the active video 3000ms of dedicated network bandwidth to stream smoothly
    // before starting heavy background precaching downloads.
    _precacheTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted || _currentPageNotifier.value != index) return;
      _precacheAround(index);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _precacheTimer?.cancel();
    _verticalController.dispose();
    _currentPageNotifier.dispose();
    ReelsVideoControllerPool.instance.releaseSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          physics: const SmoothReelsScrollPhysics(),
          allowImplicitScrolling:
              true, // Pre-build adjacent pages for 0ms swiping
          padEnds: false,
          itemCount: widget.allProducts.length,
          onPageChanged: (index) {
            _currentPageNotifier.value = index;
            // Activate pre-warmed slot immediately (URL must match ProductVideoItem)
            if (index >= 0 && index < widget.allProducts.length) {
              final prod = widget.allProducts[index];
              final vUrl = prod.effectiveVideoUrl;
              if (vUrl.isNotEmpty) {
                final clean = _resolveVideoUrl(vUrl);
                ReelsVideoControllerPool.instance.activateVideo(
                  itemIndex: index,
                  url: clean,
                  nextUrls: _getUpcomingVideoUrls(index),
                  prevUrl: _getPreviousVideoUrl(index),
                  secondPrevUrl: _getSecondPreviousVideoUrl(index),
                );
              }
            }
            _schedulePrecacheAround(index);
          },
          itemBuilder: (context, index) {
            final product = widget.allProducts[index];
            return RepaintBoundary(
              child: _KeepAliveWrapper(
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentPageNotifier,
                  builder: (context, currentPage, child) {
                    final isActive = index == currentPage && !_isScreenPaused;
                    return ProductMediaGallery(
                      key: ValueKey('gallery_${product.id}'),
                      product: product,
                      itemIndex: index,
                      isActive: isActive,
                      isMuted: _isMuted,
                      onMuteToggle: () {
                        setState(() => _isMuted = !_isMuted);
                        ReelsVideoControllerPool.instance.toggleMute();
                      },
                      isExpanded: isExpanded,
                      upcomingUrls: _getUpcomingVideoUrls(index),
                      onPause: () {
                        if (mounted) setState(() => _isScreenPaused = true);
                        ReelsVideoControllerPool.instance.pauseAll();
                      },
                      onResume: () {
                        if (mounted) setState(() => _isScreenPaused = false);
                        ReelsVideoControllerPool.instance.resume(force: true);
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
