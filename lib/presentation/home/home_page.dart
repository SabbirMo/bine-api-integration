import 'package:binetatour/presentation/home/widget/category_section_header.dart';
import 'package:binetatour/presentation/home/widget/circular_story_avatar.dart';
import 'package:binetatour/presentation/home/widget/notificaiton_screen.dart';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:binetatour/presentation/home/widget/video_widget.dart';
import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:binetatour/presentation/shop/widget/cart_screen.dart';
import 'package:binetatour/presentation/shop/widget/product_details.dart';
import 'package:binetatour/presentation/shop/widget/shop_product_card.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/home_provider.dart';
import 'package:binetatour/data/models/home_response_model.dart';
import 'package:binetatour/data/models/product_model.dart' as shop_model;
import 'package:url_launcher/url_launcher.dart';
import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/fcm_notification/firebase_service.dart';

class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen>
    with WidgetsBindingObserver {
  Future<void> _refreshHomeData() async {
    await Future.wait([
      context.read<HomeProvider>().fetchHomeData(),
      context.read<CartProvider>().fetchCart(),
      context.read<NotificationProvider>().fetchNotifications(
        forceRefresh: true,
      ),
    ]);
  }

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.removeObserver(this);
    FirebaseService.instance.onNotificationReceived = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed from background: refreshing notifications...");
      if (mounted) {
        context
            .read<NotificationProvider>()
            .fetchNotifications(forceRefresh: true)
            .catchError((e) {
              debugPrint("Error refreshing notifications on resume: $e");
            });
      }
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
                Text(
                  "ya tou ceux qu' il me faut",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () async {
              const String phoneNumber =
                  ""; // Optional support phone number e.g. "221770000000"

              final String cleanPhone = phoneNumber.replaceAll(
                RegExp(r'[^\d]'),
                '',
              );

              final Uri whatsappAppUrl = cleanPhone.isNotEmpty
                  ? Uri.parse("whatsapp://send?phone=$cleanPhone")
                  : Uri.parse("whatsapp://");

              final Uri whatsappWebUrl = cleanPhone.isNotEmpty
                  ? Uri.parse("https://wa.me/$cleanPhone")
                  : Uri.parse("https://wa.me");

              bool launched = false;

              // 1. Try launching the WhatsApp app directly
              try {
                launched = await launchUrl(
                  whatsappAppUrl,
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                launched = false;
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
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NotificationScreen()),
                      );
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
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CartBottomSheet(),
                  );
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
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8500A)),
            );
          }

          if (provider.errorMessage != null) {
            return Center(child: Text("Error: ${provider.errorMessage}"));
          }

          final homeData = provider.homeData;
          if (homeData == null) {
            return const Center(child: Text("No Data Available"));
          }

          return RefreshIndicator(
            color: const Color(0xFFE8500A),
            onRefresh: _refreshHomeData,
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
                          thumbnailUrl:
                              homeData.banner!.thumbnailUrl ??
                              "https://static.vecteezy.com/system/resources/thumbnails/071/262/006/small_2x/close-up-of-a-person-walking-with-colorful-shopping-bags-in-a-bright-mall-free-video.jpg",
                          link: homeData.banner!.videoUrl ?? "",
                        ),
                      ),
                    ),

                  // Address Section
                  if (homeData.storeAddress != null)
                    _buildAddressBar(homeData.storeAddress!),

                  _buildSectionHeader(
                    "Clients Livrés 🙍‍♂️",
                    "assets/icon/right.svg",
                    titelIcon: true,
                    showMore: true,
                  ),

                  // Stories List
                  if (homeData.storyCategories.isNotEmpty)
                    _buildStoryListDynamic(homeData.storyCategories),

                  // Product Sections
                  ...homeData.productSections.map((section) {
                    return ProductSectionWidget(section: section);
                  }),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddressBar(String address) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text("Adresse :", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 6),
          Expanded(
            child: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String titleIconPath, {
    bool showMore = false,
    bool titelIcon = false,
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
            Container(
              width: 35,
              height: 35,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xffFF6900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoryListDynamic(List<StoryCategoryModel> storyCategories) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: storyCategories.length,
        itemBuilder: (context, index) {
          final cat = storyCategories[index];

          // Resolve absolute URL for category image if it is relative
          String catImg = cat.imageUrl ?? '';
          if (catImg.isNotEmpty && !catImg.startsWith('http')) {
            final base = BaseUrl.baseUrl;
            if (catImg.startsWith('/')) {
              catImg = '$base$catImg';
            } else {
              catImg = '$base/$catImg';
            }
          }

          final String type = (cat.type ?? '').toLowerCase().trim();
          final bool isMixed = type == 'mixed';
          final bool isVideo = type == 'video';
          final bool isAudio = type == 'audio';

          final sItem = StoryItem(
            title: cat.name ?? "Story",
            imagePath: catImg.isNotEmpty ? catImg : "assets/images/footbal.jpg",
            isDashed: isMixed,
            isVideo: isVideo,
            isAudio: isAudio,
          );

          // Map API stories to StoryContent list
          final mappedStories = cat.stories
              .where((s) => s.mediaUrl != null && s.mediaUrl!.trim().isNotEmpty)
              .map((s) {
                String url = s.mediaUrl ?? '';
                // Resolve absolute URL for media URL if it is relative
                if (url.isNotEmpty && !url.startsWith('http')) {
                  final base = BaseUrl.baseUrl;
                  if (url.startsWith('/')) {
                    url = '$base$url';
                  } else {
                    url = '$base/$url';
                  }
                }

                final String cType = (s.contentType ?? '').toLowerCase().trim();
                final String lowerUrl = url.toLowerCase();
                bool isVid =
                    cType == 'video' ||
                    lowerUrl.endsWith('.mp4') ||
                    lowerUrl.endsWith('.mov') ||
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

                // Fallback: if none is detected, treat as image
                if (!isVid && !isImg && !isAud) {
                  isImg = true;
                }

                return StoryContent(
                  id: s.id,
                  url: url,
                  isVideo: isVid,
                  isAudio: isAud,
                  isImage: isImg,
                  isNetwork: url.startsWith('http'),
                  createdAt: s.createdAt,
                );
              })
              .toList();

          return InkWell(
            onTap: () {
              if (mappedStories.isEmpty) return; // Prevent opening if empty
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoryDetailScreen(
                    stories: mappedStories,
                    userName: cat.name ?? "Story",
                    userProfile: catImg.isNotEmpty
                        ? catImg
                        : "https://images.pexels.com/photos/771742/pexels-photo-771742.jpeg",
                  ),
                ),
              );
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

  const ProductSectionWidget({super.key, required this.section});

  @override
  State<ProductSectionWidget> createState() => _ProductSectionWidgetState();
}

class _ProductSectionWidgetState extends State<ProductSectionWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.section.products.isEmpty) {
      return const SizedBox(); // Don't show empty categories
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        CategorySectionHeader(
          title: widget.section.categoryName ?? 'Category',
          imagePath: widget.section.categoryImageUrl,
          onSeeMoreTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BoutiqueScreen(
                  initialCategoryId: widget.section.categoryId,
                ),
              ),
            );
          },
        ),

        _buildVideoHorizontalListDynamic(
          widget.section.products,
          widget.section.categoryName ?? 'Category',
        ),
      ],
    );
  }

  Widget _buildVideoHorizontalListDynamic(
    List<ProductModel> allProducts,
    String categoryName,
  ) {
    final double screenWidth = MediaQuery.of(context).size.width;
    // Total padding of ListView: 16 * 2 = 32
    // Spacing between cards: 12 * 2 = 24
    // cardWidth = (screenWidth - 32 - 24) / 3
    final double cardWidth = (screenWidth - 56) / 2.9;
    final double cardHeight =
        cardWidth *
        1.72; // Adjusted height ratio to match ~0.58 aspect ratio (Figma)

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allProducts.length,
        itemBuilder: (context, index) {
          final product = allProducts[index];

          List<ProductContent> productContents = [];
          if (product.mainImage != null && product.mainImage!.isNotEmpty) {
            productContents.add(
              ProductContent(
                url: product.mainImage!,
                isVideo: false,
                isImage: true,
              ),
            );
          } else {
            productContents.add(
              ProductContent(
                url:
                    "https://images.pexels.com/photos/16479766/pexels-photo-16479766.jpeg",
                isVideo: false,
                isImage: true,
              ),
            );
          }

          double discPerc =
              double.tryParse(product.discountPercentage?.toString() ?? "0") ??
              0;

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () {
                // Convert the lightweight ProductModel into the expected full ProductModel
                final convertedProducts = allProducts
                    .map(
                      (p) => shop_model.ProductModel(
                        id: p.id,
                        productName: p.productName ?? '',
                        categoryId: widget.section.categoryId,
                        categoryName: widget.section.categoryName ?? '',
                        sellingPrice: p.sellingPrice ?? '0',
                        discountPercentage: p.discountPercentage ?? '0',
                        priceAfterDiscount: p.priceAfterDiscount ?? 0.0,
                        status: p.status ?? '',
                        mainImage: p.mainImage,
                        media: [],
                      ),
                    )
                    .toList();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(
                      allProducts: convertedProducts,
                      initialProductIndex: index,
                    ),
                  ),
                );
              },
              child: ShopProductCard(
                title: product.productName ?? "No Title",
                price:
                    "${product.priceAfterDiscount ?? product.sellingPrice} FCFA",
                oldPrice: discPerc > 0 ? "${product.sellingPrice} FCFA" : null,
                discount: discPerc > 0 ? "-${discPerc.toInt()}%" : null,
                showDiscountPercentage: discPerc > 0,
                showOldPrice: discPerc > 0,
                assetThumbnail: product.mainImage,
                content: productContents,
                width: cardWidth,
                height: cardHeight,
                isCompact: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Keep original dummy classes below so imports in other files don't break
class Product {
  final String title;
  final String price;
  final String? oldPrice;
  final String? discount;
  final String assetThumbnail;
  final String videoUrl;
  final String category;

  Product({
    required this.title,
    required this.price,
    this.oldPrice,
    this.discount,
    required this.assetThumbnail,
    required this.videoUrl,
    required this.category,
  });
}

class StoryItem {
  final String title;
  final String imagePath;
  final bool isDashed;
  final bool isVideo;
  final bool isAudio;

  StoryItem({
    required this.title,
    required this.imagePath,
    this.isDashed = false,
    this.isVideo = false,
    this.isAudio = false,
  });
}
