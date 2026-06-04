import 'package:binetatour/presentation/home/widget/category_section_header.dart';
import 'package:binetatour/presentation/home/widget/circular_story_avatar.dart';
import 'package:binetatour/presentation/home/widget/notificaiton_screen.dart';
import 'package:binetatour/presentation/home/widget/story_details.dart';
import 'package:binetatour/presentation/home/widget/video_widget.dart';
import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:binetatour/presentation/shop/widget/cart_screen.dart';
import 'package:binetatour/presentation/shop/widget/product_details.dart';
import 'package:binetatour/presentation/shop/widget/shop_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/home_provider.dart';
import 'package:binetatour/data/models/home_response_model.dart';

class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchHomeData();
    });
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
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "ya tou ceux qu' il me faut",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          SvgPicture.asset("assets/icon/whatsapp.svg"),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationScreen()),
              );
            },
            icon: const Icon(Icons.notifications_none, color: Colors.black),
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
                top: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xffF85000),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text("1", style: TextStyle(color: Colors.white)),
                    ),
                  ),
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

          return SingleChildScrollView(
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
                        link:
                            homeData.banner!.videoUrl ??
                            "https://www.pexels.com/download/video/36418671/",
                      ),
                    ),
                  ),

                // Address Section
                if (homeData.storeAddress != null)
                  _buildAddressBar(homeData.storeAddress!),

                _buildSectionHeader(
                  "Clients Livrés 🏆",
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
          SizedBox(width: 4),
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
          final sItem = StoryItem(
            title: cat.name ?? "Story",
            imagePath: cat.imageUrl ?? "assets/images/footbal.jpg",
            isDashed: true,
          );

          // Map API stories to StoryContent list
          final mappedStories = cat.stories.map((s) {
            bool isVid = s.contentType == 'video';
            bool isImg = s.contentType == 'image';
            return StoryContent(
              url: s.mediaUrl ?? '',
              isVideo: isVid,
              isAudio: false,
              isImage: isImg,
              isNetwork: s.mediaUrl?.startsWith('http') ?? false,
            );
          }).toList();

          return InkWell(
            onTap: () {
              if (mappedStories.isEmpty) return; // Prevent opening if empty
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoryDetailScreen(
                    stories: mappedStories,
                    userName: cat.name ?? "Story",
                    userProfile:
                        cat.imageUrl ??
                        "https://images.pexels.com/photos/771742/pexels-photo-771742.jpeg",
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
  final ScrollController _scrollController = ScrollController();

  void _scrollNext() {
    if (_scrollController.hasClients) {
      double currentOffset = _scrollController.offset;
      double itemWidth = 180.0 + 12.0; // 180 width + 12 padding right
      double targetOffset = currentOffset + (itemWidth * 2);

      if (targetOffset > _scrollController.position.maxScrollExtent) {
        targetOffset = _scrollController.position.maxScrollExtent;
      }

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CategorySectionHeader(
          title: widget.section.categoryName ?? 'Category',
          imagePath: widget.section.categoryImageUrl,
          onSeeMoreTap: _scrollNext,
        ),
        _buildVideoHorizontalListDynamic(
          widget.section.products,
          widget.section.categoryName ?? 'Category',
          _scrollController,
        ),
      ],
    );
  }

  Widget _buildVideoHorizontalListDynamic(
    List<ProductModel> allProducts,
    String categoryName,
    ScrollController scrollController,
  ) {
    return SizedBox(
      height: 260,
      child: ListView.builder(
        controller: scrollController,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(allProducts: []),
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

  StoryItem({
    required this.title,
    required this.imagePath,
    this.isDashed = false,
    this.isVideo = false,
  });
}

final myStories = [
  StoryContent(
    url: 'https://www.pexels.com/download/video/4398957/',
    isVideo: true,
    isAudio: false,
    isImage: false,
    isNetwork: true,
  ),
  StoryContent(
    url: 'https://images.pexels.com/photos/17943742/pexels-photo-17943742.jpeg',
    isVideo: false,
    isAudio: false,
    isImage: true,
    isNetwork: true,
  ),
];
