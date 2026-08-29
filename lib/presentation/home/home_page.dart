import 'package:binetatour/core/video/feed_video_manager.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:binetatour/presentation/home/widget/category_section_header.dart';
import 'package:binetatour/presentation/home/widget/circular_story_avatar.dart';
import 'package:binetatour/presentation/home/widget/notificaiton_screen.dart';
import 'package:binetatour/presentation/home/widget/shorts_product_card.dart';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:binetatour/presentation/home/widget/video_widget.dart';
import 'package:binetatour/presentation/home/widget/home_skeleton_loader.dart';
import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:binetatour/presentation/shop/widget/cart_screen.dart';
import 'package:binetatour/presentation/shop/widget/product_details.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/notification_provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/home_provider.dart';
import 'package:binetatour/data/models/home_response_model.dart';
import 'package:binetatour/data/models/product_model.dart' as shop_model;
import 'package:url_launcher/url_launcher.dart';
import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/fcm_notification/firebase_service.dart';
import 'package:binetatour/core/login/login_provider.dart';

class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen>
    with WidgetsBindingObserver {
  final ScrollController _storyScrollController = ScrollController();
  bool _storiesPrecached = false;
  bool _productsPrecached = false;

  Future<void> _refreshHomeData() async {
    try {
      _storiesPrecached = false;
      _productsPrecached = false;
      // Fetch Home Data with highest priority (fastest UI update) with timeout
      await context.read<HomeProvider>().fetchHomeData().timeout(
        const Duration(seconds: 6),
      );
    } catch (e) {
      debugPrint("Home refresh error or timeout: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    VideoCacheManager.instance.init();
    WidgetsBinding.instance.addObserver(this);

    // Auto-refresh notifications and update bell count when a foreground notification is received
    FirebaseService.instance.onNotificationReceived = () {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications(
          forceRefresh: true,
        );
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHomeData();
    });
  }

  @override
  void dispose() {
    FeedVideoManager.instance.pauseAll();
    _storyScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    FirebaseService.instance.onNotificationReceived = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FeedVideoManager.instance.resume();
      debugPrint("App resumed from background: refreshing notifications...");
      if (mounted) {
        context
            .read<NotificationProvider>()
            .fetchNotifications(forceRefresh: true)
            .catchError((e) {
              debugPrint("Error refreshing notifications on resume: $e");
            });
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      FeedVideoManager.instance.pauseAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset("assets/images/home.png", height: 45, width: 45),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Bawane",
                  style: TextStyle(
                    color: Color(0xFFE8500A),
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
                const Text(
                  "Satisfait ou remboursé",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ], // nothing
        ),
        actions: [
          GestureDetector(
            onTap: () async {
              final String phoneNumber = dotenv.env["WHATSAPP_PHONE"] ?? "";

              final String cleanPhone = phoneNumber.replaceAll(
                RegExp(r'[^\d]'),
                ' ',
              );

              const String defaultMessage =
                  "Bonjour, je visite votre site web et j'aimerais avoir des informations.";
              final String encodedMsg = Uri.encodeComponent(defaultMessage);

              final Uri whatsappAppUrl = cleanPhone.isNotEmpty
                  ? Uri.parse(
                      "whatsapp://send?phone=$cleanPhone&text=$encodedMsg",
                    )
                  : Uri.parse("whatsapp://send?text=$encodedMsg");

              final Uri whatsappWebUrl = cleanPhone.isNotEmpty
                  ? Uri.parse("https://wa.me/$cleanPhone?text=$encodedMsg")
                  : Uri.parse("https://wa.me?text=$encodedMsg");

              bool launched = false;

              // 1. Try launching the WhatsApp app directly
              try {
                launched = await launchUrl(
                  whatsappAppUrl,
                  mode: LaunchMode.externalNonBrowserApplication,
                );
              } catch (e) {
                launched = false;
              }

              if (!launched) {
                try {
                  launched = await launchUrl(
                    whatsappAppUrl,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  launched = false;
                }
              }

              // 2. Fallback to web if WhatsApp app is not installed
              if (!launched) {
                try {
                  launched = await launchUrl(
                    whatsappWebUrl,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  launched = false;
                }
              }

              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not launch WhatsApp')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SvgPicture.asset("assets/icon/whatsapp.svg"),
            ),
          ),
          Consumer<LoginProvider>(
            builder: (context, loginProvider, child) {
              if (!loginProvider.isLoggedIn) {
                return const SizedBox.shrink();
              }
              return Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () async {
                          FeedVideoManager.instance.pauseAll();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NotificationScreen(),
                            ),
                          );
                          FeedVideoManager.instance.resume();
                        },
                        icon: const Icon(
                          Icons.notifications_none,
                          color: Colors.black,
                        ),
                      ),
                      if (notificationProvider.unreadCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6900),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              notificationProvider.unreadCount > 99
                                  ? '99+'
                                  : notificationProvider.unreadCount.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  FeedVideoManager.instance.pauseAll();
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CartBottomSheet(),
                  );
                  FeedVideoManager.instance.resume();
                },
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.black,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final totalItems = cartProvider.cart?.items.length ?? 0;
                    if (totalItems == 0) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xffF85000),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        totalItems.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<HomeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const HomeSkeletonLoader();
          }

          if (provider.errorMessage != null) {
            return RefreshIndicator(
              color: const Color(0xFFE8500A),
              onRefresh: _refreshHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Error: ${provider.errorMessage}"),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshHomeData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8500A),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Réessayer"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final homeData = provider.homeData;
          if (homeData == null) {
            return RefreshIndicator(
              color: const Color(0xFFE8500A),
              onRefresh: _refreshHomeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(child: Text("No Data Available")),
                ),
              ),
            );
          }

          if (homeData.productSections.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _precacheProductThumbnails(homeData.productSections);
                _precacheProductVideos(homeData.productSections);
              }
            });
          }

          return RefreshIndicator(
            color: const Color(0xFFE8500A),
            onRefresh: _refreshHomeData,
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                VisibilityDetectorController.instance.notifyNow();
                final maxScroll = scrollInfo.metrics.maxScrollExtent;
                final pixels = scrollInfo.metrics.pixels;
                final ratio = maxScroll > 0
                    ? (pixels / maxScroll).clamp(0.0, 1.0)
                    : 0.0;
                FeedVideoManager.instance.updateScrollRatio(ratio);
                final isBottom =
                    maxScroll > 0 &&
                    (scrollInfo.metrics.extentAfter <= 50 ||
                        pixels >= maxScroll - 50);
                FeedVideoManager.instance.setIsAtBottom(isBottom);
                return false;
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Banner Video
                    if (homeData.banner != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: VideoPlaceholder(
                            thumbnailUrl: homeData.banner!.thumbnailUrl,
                            link: homeData.banner!.effectiveVideoUrl,
                            fallbackLink: homeData.banner!.videoUrl,
                          ),
                        ),
                      ),

                    // Address Section
                    // if (homeData.storeAddress != null)
                    //   _buildAddressBar(homeData.storeAddress!),
                    _buildSectionHeader(
                      "Clients Livrés 🙍‍♂️",
                      "assets/icon/right.svg",
                      titelIcon: true,
                      showMore: true,
                      onShowMoreTap: () {
                        if (_storyScrollController.hasClients) {
                          double targetOffset =
                              _storyScrollController.offset + 250;
                          double maxScroll =
                              _storyScrollController.position.maxScrollExtent;
                          if (targetOffset > maxScroll) {
                            targetOffset = maxScroll;
                          }

                          _storyScrollController.animateTo(
                            targetOffset,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),

                    // Stories List
                    if (homeData.storyCategories.isNotEmpty)
                      _buildStoryListDynamic(homeData.storyCategories),

                    // Product Sections
                    ...homeData.productSections.map((section) {
                      return ProductSectionWidget(
                        section: section,
                        allSections: homeData.productSections,
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget _buildAddressBar(String address) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFFFFF1E6),
  //       borderRadius: BorderRadius.circular(10),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(Icons.location_on_outlined, color: Colors.orange, size: 20),
  //         SizedBox(width: 8),
  //         Text("Adresse :", style: TextStyle(fontWeight: FontWeight.bold)),
  //         SizedBox(width: 6),
  //         Expanded(
  //           child: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSectionHeader(
    String title,
    String titleIconPath, {
    bool showMore = false,
    bool titelIcon = false,
    VoidCallback? onShowMoreTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (titelIcon) ...[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: SvgPicture.asset(titleIconPath, fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showMore)
            InkWell(
              onTap: onShowMoreTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _precacheStoryThumbnails(List<StoryCategoryModel> categories) {
    if (_storiesPrecached || categories.isEmpty) return;
    _storiesPrecached = true;

    for (final cat in categories) {
      String catImg = cat.imageUrl ?? '';
      if (catImg.isNotEmpty && !catImg.startsWith('http')) {
        final base = BaseUrl.baseUrl;
        catImg = catImg.startsWith('/') ? '$base$catImg' : '$base/$catImg';
      }
      if (catImg.startsWith('http')) {
        precacheImage(NetworkImage(catImg), context).catchError((_) {});
      }

      for (final story in cat.stories) {
        String? thumb = story.thumbnailUrl;
        if (thumb != null &&
            thumb.trim().isNotEmpty &&
            !thumb.startsWith('http')) {
          final base = BaseUrl.baseUrl;
          thumb = thumb.startsWith('/') ? '$base$thumb' : '$base/$thumb';
        }
        if (thumb != null && thumb.startsWith('http')) {
          precacheImage(NetworkImage(thumb), context).catchError((_) {});
        }
      }
    }
  }

  void _precacheProductThumbnails(List<ProductSectionModel> sections) {
    if (_productsPrecached || sections.isEmpty) return;
    _productsPrecached = true;

    for (final sec in sections) {
      for (final prod in sec.products) {
        String thumb = prod.effectiveThumbnailUrl;
        if (thumb.isNotEmpty && !thumb.startsWith('http')) {
          final base = BaseUrl.baseUrl;
          thumb = thumb.startsWith('/') ? '$base$thumb' : '$base/$thumb';
        }
        if (thumb.startsWith('http')) {
          precacheImage(NetworkImage(thumb), context).catchError((_) {});
        }
      }
    }
  }

  void _precacheProductVideos(List<ProductSectionModel> sections) {
    // Disabled aggressive background caching. We now use native media_kit preloading.
  }

  StoryGroup _mapCategoryToStoryGroup(StoryCategoryModel cat) {
    String catImg = cat.imageUrl ?? '';
    if (catImg.isNotEmpty && !catImg.startsWith('http')) {
      final base = BaseUrl.baseUrl;
      catImg = catImg.startsWith('/') ? '$base$catImg' : '$base/$catImg';
    }

    final String type = (cat.type ?? '').toLowerCase().trim();
    final bool isVideo = type == 'video';
    final bool isAudio = type == 'audio';

    final mappedStories = cat.stories
        .where((s) => s.effectiveMediaUrl.trim().isNotEmpty)
        .map((s) {
          String url = s.effectiveMediaUrl;
          if (url.isNotEmpty && !url.startsWith('http')) {
            final base = BaseUrl.baseUrl;
            url = url.startsWith('/') ? '$base$url' : '$base/$url';
          }

          final String cType = (s.contentType ?? '').toLowerCase().trim();
          final String lowerUrl = url.toLowerCase();
          bool isVid =
              cType == 'video' ||
              isVideo ||
              lowerUrl.contains('.m3u8') ||
              lowerUrl.contains('.mp4') ||
              lowerUrl.endsWith('.mov') ||
              lowerUrl.endsWith('.webm') ||
              lowerUrl.endsWith('.mkv') ||
              lowerUrl.endsWith('.avi');
          bool isImg =
              cType == 'image' ||
              lowerUrl.endsWith('.png') ||
              lowerUrl.endsWith('.jpg') ||
              lowerUrl.endsWith('.jpeg') ||
              lowerUrl.endsWith('.webp') ||
              lowerUrl.endsWith('.gif');
          bool isAud =
              cType == 'audio' ||
              lowerUrl.endsWith('.mp3') ||
              lowerUrl.endsWith('.wav') ||
              lowerUrl.endsWith('.aac') ||
              lowerUrl.endsWith('.m4a');

          if (!isVid && !isImg && !isAud) {
            isImg = true;
          }

          String? resolvedThumb = s.thumbnailUrl;
          if (resolvedThumb != null &&
              resolvedThumb.trim().isNotEmpty &&
              !resolvedThumb.startsWith('http')) {
            final base = BaseUrl.baseUrl;
            resolvedThumb = resolvedThumb.startsWith('/')
                ? '$base$resolvedThumb'
                : '$base/$resolvedThumb';
          }

          return StoryContent(
            id: s.id,
            url: url,
            fallbackUrl: s.mediaUrl,
            thumbnailUrl: resolvedThumb,
            isVideo: isVid,
            isAudio: isAud,
            isImage: isImg,
            isNetwork: url.startsWith('http'),
            createdAt: s.createdAt,
          );
        })
        .toList();

    return StoryGroup(
      categoryId: cat.id,
      categoryName: cat.name ?? "Story",
      categoryImage: catImg.isNotEmpty ? catImg : "",
      stories: mappedStories,
      isVideo: isVideo,
      isAudio: isAudio,
    );
  }

  Widget _buildStoryListDynamic(List<StoryCategoryModel> storyCategories) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _precacheStoryThumbnails(storyCategories);
      }
    });

    final allGroups = storyCategories
        .map((cat) => _mapCategoryToStoryGroup(cat))
        .where((g) => g.stories.isNotEmpty)
        .toList();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        controller: _storyScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: storyCategories.length,
        itemBuilder: (context, index) {
          final cat = storyCategories[index];
          final catGroup = _mapCategoryToStoryGroup(cat);
          final mappedStories = catGroup.stories;

          final int sCount = mappedStories.isNotEmpty
              ? mappedStories.length
              : (cat.stories.isNotEmpty ? cat.stories.length : 1);

          final sItem = StoryItem(
            title: cat.name ?? "Story",
            imagePath: catGroup.categoryImage,
            isDashed: sCount > 1,
            storyCount: sCount,
            isVideo: catGroup.isVideo,
            isAudio: catGroup.isAudio,
          );

          return InkWell(
            onTap: () async {
              if (mappedStories.isEmpty) return; // Prevent opening if empty

              int initialGroupIndex = allGroups.indexWhere(
                (g) => g.categoryId == cat.id,
              );
              if (initialGroupIndex < 0) initialGroupIndex = 0;

              FeedVideoManager.instance.pauseAll();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoryDetailScreen(
                    storyGroups: allGroups,
                    initialGroupIndex: initialGroupIndex,
                  ),
                ),
              );
              FeedVideoManager.instance.resume();
            },
            child: CircularStoryAvatar(item: sItem),
          );
        },
      ),
    );
  }
}

class ProductSectionWidget extends StatefulWidget {
  final ProductSectionModel section;
  final List<ProductSectionModel>? allSections;

  const ProductSectionWidget({
    super.key,
    required this.section,
    this.allSections,
  });

  @override
  State<ProductSectionWidget> createState() => _ProductSectionWidgetState();
}

class _ProductSectionWidgetState extends State<ProductSectionWidget> {
  final ScrollController _scrollController = ScrollController();
  int _activeCardIndex = 0;

  @override
  void initState() {
    super.initState();
    FeedVideoManager.instance.registerSectionContext(
      widget.section.categoryId.toString(),
      context,
    );
    _scrollController.addListener(_onHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheSectionVideos();
      _notifySectionActiveCard();
    });
  }

  @override
  void didUpdateWidget(ProductSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    FeedVideoManager.instance.registerSectionContext(
      widget.section.categoryId.toString(),
      context,
    );
    if (oldWidget.section.products != widget.section.products) {
      _precacheSectionVideos();
      _notifySectionActiveCard();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onHorizontalScroll);
    _scrollController.dispose();
    FeedVideoManager.instance.unregisterSectionContext(
      widget.section.categoryId.toString(),
    );
    FeedVideoManager.instance.unregisterSection(
      widget.section.categoryId.toString(),
    );
    super.dispose();
  }

  void _onHorizontalScroll() {
    if (!mounted || widget.section.products.isEmpty) return;
    final totalCount = widget.section.products.length;
    if (totalCount <= 1) return;

    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final maxScroll = position.maxScrollExtent;
      final offset = position.pixels;

      int newIndex;
      if (maxScroll <= 0) {
        newIndex = 0;
      } else if (offset <= 10) {
        newIndex = 0;
      } else if (offset >= maxScroll - 10) {
        newIndex = totalCount - 1;
      } else {
        final progress = (offset / maxScroll).clamp(0.0, 1.0);
        newIndex = (progress * (totalCount - 1)).round().clamp(
          0,
          totalCount - 1,
        );
      }

      if (newIndex != _activeCardIndex) {
        setState(() {
          _activeCardIndex = newIndex;
        });
        _notifySectionActiveCard();
      }
    }
  }

  void _notifySectionActiveCard() {
    if (widget.section.products.isEmpty) return;
    final productProvider = context.read<ProductProvider>();
    final activeProd = widget.section.products[_activeCardIndex];
    final vUrl = _resolveProductVideo(activeProd, productProvider);
    final key = 'feed_prod_${widget.section.categoryId}_${activeProd.id}';
    FeedVideoManager.instance.setActiveSectionCard(
      widget.section.categoryId.toString(),
      key,
      vUrl,
    );
  }

  void _reportSectionVisibility(double fraction) {
    if (!mounted) return;
    double centerY = 0.0;
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final globalOffset = renderBox.localToGlobal(Offset.zero);
        centerY = globalOffset.dy + (renderBox.size.height / 2);
      }
    } catch (_) {}

    FeedVideoManager.instance.updateSectionVisibility(
      widget.section.categoryId.toString(),
      fraction,
      centerY,
    );
  }

  void _precacheSectionVideos() {
    final productProvider = context.read<ProductProvider>();
    for (final prod in widget.section.products) {
      final vUrl = _resolveProductVideo(prod, productProvider);
      if (vUrl.isNotEmpty) {
        VideoCacheManager.instance.preCacheVideo(vUrl);
      }
    }
  }

  String _resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String clean = url.trim();
    if (!clean.startsWith('http')) {
      final base = BaseUrl.baseUrl;
      clean = clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }
    return clean;
  }

  bool _isVideoUrl(String url) {
    if (url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase().split('?').first.split('#').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.m3u8') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.flv') ||
        clean.endsWith('.3gp') ||
        clean.contains('.mp4') ||
        clean.contains('.m3u8');
  }

  String _resolveProductVideo(
    ProductModel product,
    ProductProvider productProvider,
  ) {
    String vUrl = product.effectiveVideoUrl;
    if (vUrl.isNotEmpty) {
      return _resolveUrl(vUrl);
    }

    // Check if ProductProvider cached full product with video media
    final matching = productProvider.getCachedProduct(product.id);
    if (matching != null) {
      for (final m in matching.media) {
        final mType = m.mediaType.toLowerCase().trim();
        final mUrl = m.effectiveMediaUrl;
        if ((mType == 'video' || _isVideoUrl(mUrl)) && mUrl.isNotEmpty) {
          return _resolveUrl(mUrl);
        }
      }
      if (matching.mainImage != null && _isVideoUrl(matching.mainImage!)) {
        return _resolveUrl(matching.mainImage!);
      }
    }

    // Check if mainImage is a video
    if (product.mainImage != null && _isVideoUrl(product.mainImage!)) {
      return _resolveUrl(product.mainImage!);
    }

    return '';
  }

  String _resolveProductThumbnail(
    ProductModel product,
    ProductProvider productProvider,
  ) {
    // 1. Direct thumbnail from home API
    String tUrl = product.effectiveThumbnailUrl;
    if (tUrl.isNotEmpty) return _resolveUrl(tUrl);

    // 2. Direct mainImage if not a video
    if (product.mainImage != null && !_isVideoUrl(product.mainImage!)) {
      return _resolveUrl(product.mainImage!);
    }

    // 3. Check media items from product
    for (final m in product.safeMedia) {
      if (m.thumbnailUrl != null && m.thumbnailUrl!.trim().isNotEmpty) {
        return _resolveUrl(m.thumbnailUrl!);
      }
      if (m.mediaType.toLowerCase() == 'image' &&
          m.effectiveMediaUrl.isNotEmpty) {
        return _resolveUrl(m.effectiveMediaUrl);
      }
    }

    // 4. Cached product detail (if already in memory cache)
    final cached = productProvider.getCachedProduct(product.id);
    if (cached != null) {
      final cThumb = cached.effectiveThumbnailUrl;
      if (cThumb.isNotEmpty) return _resolveUrl(cThumb);
      for (final m in cached.media) {
        if (m.thumbnailUrl != null && m.thumbnailUrl!.trim().isNotEmpty) {
          return _resolveUrl(m.thumbnailUrl!);
        }
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section.products.isEmpty) {
      return const SizedBox(); // Don't show empty categories
    }

    final productProvider = context.watch<ProductProvider>();

    return VisibilityDetector(
      key: Key('sec_${widget.section.categoryId}'),
      onVisibilityChanged: (info) =>
          _reportSectionVisibility(info.visibleFraction),
      child: Column(
        children: [
          const SizedBox(height: 10),
          CategorySectionHeader(
            title: widget.section.categoryName ?? 'Category',
            imagePath: _resolveUrl(widget.section.categoryImageUrl),
            onSeeMoreTap: () async {
              FeedVideoManager.instance.pauseAll();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BoutiqueScreen(
                    initialCategoryId: widget.section.categoryId,
                    showBackButton: true,
                  ),
                ),
              );
              FeedVideoManager.instance.resume();
            },
          ),

          _buildVideoHorizontalListDynamic(
            widget.section.products,
            widget.section.categoryName ?? 'Category',
            productProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoHorizontalListDynamic(
    List<ProductModel> allProducts,
    String categoryName,
    ProductProvider productProvider,
  ) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth - 40) / 2;
    final double cardHeight = cardWidth * 1.48;

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allProducts.length,
        itemBuilder: (context, index) {
          final product = allProducts[index];
          final String resolvedVideo = _resolveProductVideo(
            product,
            productProvider,
          );
          final String resolvedThumbnail = _resolveProductThumbnail(
            product,
            productProvider,
          );

          double discPerc =
              double.tryParse(product.discountPercentage?.toString() ?? "0") ??
              0;

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ShortsProductCard(
              keyString: 'feed_prod_${widget.section.categoryId}_${product.id}',
              videoUrl: resolvedVideo,
              thumbnailUrl: resolvedThumbnail,
              title: product.productName ?? "No Title",
              price:
                  "${(product.priceAfterDiscount != null && product.priceAfterDiscount!.isNotEmpty) ? product.priceAfterDiscount : product.sellingPrice} FCFA",
              oldPrice: discPerc > 0 ? "${product.sellingPrice} FCFA" : null,
              discount: discPerc > 0 ? "-${discPerc.toInt()}%" : null,
              width: cardWidth,
              height: cardHeight,
              onTap: () async {
                setState(() {
                  _activeCardIndex = index;
                });
                _notifySectionActiveCard();

                FeedVideoManager.instance.pauseAll();

                final sectionsToUse =
                    (widget.allSections != null &&
                        widget.allSections!.isNotEmpty)
                    ? widget.allSections!
                    : [widget.section];

                final List<shop_model.ProductModel> convertedProducts = [];
                final Set<int> addedIds = {};
                int targetInitialIndex = 0;

                for (final sec in sectionsToUse) {
                  for (final p in sec.products) {
                    if (addedIds.contains(p.id)) continue;
                    addedIds.add(p.id);

                    if (sec.categoryId == widget.section.categoryId &&
                        p.id == product.id) {
                      targetInitialIndex = convertedProducts.length;
                    }

                    final full = productProvider.getCachedProduct(p.id);
                    if (full != null) {
                      convertedProducts.add(full);
                      continue;
                    }

                    List<shop_model.MediaModel> mediaList = [];
                    if (p.safeMedia.isNotEmpty) {
                      mediaList = p.safeMedia;
                    } else if (p.effectiveVideoUrl.isNotEmpty) {
                      mediaList = [
                        shop_model.MediaModel(
                          id: 0,
                          mediaType: 'video',
                          mediaUrl: _resolveUrl(p.effectiveVideoUrl),
                          thumbnailUrl: p.mainImage,
                        ),
                      ];
                    }

                    convertedProducts.add(
                      shop_model.ProductModel(
                        id: p.id,
                        productName: p.productName ?? '',
                        categoryId: sec.categoryId,
                        categoryName: sec.categoryName ?? '',
                        sellingPrice: p.sellingPrice ?? '0',
                        discountPercentage: p.discountPercentage ?? '0',
                        priceAfterDiscount:
                            (p.priceAfterDiscount != null &&
                                p.priceAfterDiscount!.isNotEmpty)
                            ? p.priceAfterDiscount!
                            : (p.sellingPrice ?? '0'),
                        status: p.status ?? '',
                        mainImage: p.mainImage,
                        media: mediaList,
                      ),
                    );
                  }
                }

                // Precache clicked video and adjacent videos immediately for instant smooth playback
                if (convertedProducts.isNotEmpty &&
                    targetInitialIndex >= 0 &&
                    targetInitialIndex < convertedProducts.length) {
                  final indices = [
                    targetInitialIndex,
                    targetInitialIndex + 1,
                    targetInitialIndex + 2,
                    targetInitialIndex - 1,
                  ];
                  for (final idx in indices) {
                    if (idx >= 0 && idx < convertedProducts.length) {
                      final p = convertedProducts[idx];
                      final vUrl = p.effectiveVideoUrl;
                      if (vUrl.isNotEmpty) {
                        VideoCacheManager.instance.preCacheVideo(vUrl);
                      }
                    }
                  }
                }

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(
                      allProducts: convertedProducts,
                      initialProductIndex: targetInitialIndex,
                    ),
                  ),
                );

                FeedVideoManager.instance.resume();
              },
            ),
          );
        },
      ),
    );
  }
}

class StoryItem {
  final String title;
  final String imagePath;
  final bool isDashed;
  final int storyCount;
  final bool isVideo;
  final bool isAudio;

  StoryItem({
    required this.title,
    required this.imagePath,
    this.isDashed = false,
    this.storyCount = 1,
    this.isVideo = false,
    this.isAudio = false,
  });
}
