import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/video/feed_video_manager.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/core/video/video_frame_manager.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/home/widget/shorts_product_card.dart';
import 'package:binetatour/presentation/shop/widget/product_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/category_provider.dart';
import 'package:binetatour/data/models/category_model.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

class BoutiqueScreen extends StatefulWidget {
  final int? initialCategoryId;

  const BoutiqueScreen({super.key, this.initialCategoryId});

  @override
  State<BoutiqueScreen> createState() => _BoutiqueScreenState();
}

class _BoutiqueScreenState extends State<BoutiqueScreen> {
  int selectedCategory = 0;
  late ScrollController _categoryScrollController;
  String selectedCategoryName = "Tous";

  bool isSubcategoryShow = true;
  int selectedSubCategoryIndex = -1;
  bool _initialCategorySet = false;

  @override
  void initState() {
    super.initState();
    _categoryScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchCategories();
      context.read<ProductProvider>().fetchProducts();
      VisibilityDetectorController.instance.notifyNow();
    });
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
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

  String _resolveProductVideo(ProductModel product) {
    final String vUrl = product.effectiveVideoUrl;
    if (vUrl.isNotEmpty) {
      return _resolveUrl(vUrl);
    }

    for (final m in product.media) {
      final mType = m.mediaType.toLowerCase().trim();
      final mUrl = m.effectiveMediaUrl;
      if ((mType == 'video' || _isVideoUrl(mUrl)) && mUrl.isNotEmpty) {
        return _resolveUrl(mUrl);
      }
    }

    // Check if ProductProvider cached full product with video media
    final matching = context.read<ProductProvider>().getCachedProduct(
      product.id,
    );
    if (matching != null && matching != product) {
      final String matchVUrl = matching.effectiveVideoUrl;
      if (matchVUrl.isNotEmpty) {
        return _resolveUrl(matchVUrl);
      }
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

    if (product.mainImage != null && _isVideoUrl(product.mainImage!)) {
      return _resolveUrl(product.mainImage!);
    }
    return '';
  }

  String _resolveProductThumbnail(ProductModel product) {
    final String tUrl = product.effectiveThumbnailUrl;
    if (tUrl.isNotEmpty) {
      return _resolveUrl(tUrl);
    }
    if (product.mainImage != null && product.mainImage!.isNotEmpty) {
      return _resolveUrl(product.mainImage!);
    }
    for (final m in product.media) {
      if (m.thumbnailUrl != null && m.thumbnailUrl!.isNotEmpty) {
        return _resolveUrl(m.thumbnailUrl!);
      }
      if (m.mediaType == 'image' && m.effectiveMediaUrl.isNotEmpty) {
        return _resolveUrl(m.effectiveMediaUrl);
      }
    }
    return '';
  }

  void _precacheVideos(List<ProductModel> products) {
    final List<String> videoUrls = [];
    final productProvider = context.read<ProductProvider>();
    for (final p in products) {
      final vUrl = _resolveProductVideo(p);
      if (vUrl.isNotEmpty) {
        videoUrls.add(vUrl);
        VideoCacheManager.instance.preCacheVideo(vUrl);
      } else if (p.media.isEmpty &&
          !productProvider.isProductDetailsCached(p.id)) {
        productProvider.fetchProductDetails(p.id);
      }
    }
    if (videoUrls.isNotEmpty) {
      VideoFrameManager.instance.preExtractBatch(videoUrls);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories;
    final isLoading = categoryProvider.isLoading;

    final productProvider = context.watch<ProductProvider>();
    final isProductsLoading = productProvider.isLoading;

    if (!_initialCategorySet &&
        categories.isNotEmpty &&
        widget.initialCategoryId != null) {
      final index = categories.indexWhere(
        (c) => c.id == widget.initialCategoryId,
      );
      if (index != -1) {
        selectedCategory = index;
        selectedCategoryName = categories[index].name;
      }
      _initialCategorySet = true;
    }

    int? currentCategoryId;
    if (categories.isNotEmpty && selectedCategory < categories.length) {
      currentCategoryId = categories[selectedCategory].id;
    }

    List<SubcategoryModel> currentSubCategories = [];
    if (categories.isNotEmpty) {
      if (selectedCategory >= categories.length) {
        selectedCategory = 0;
      }
      currentSubCategories = categories[selectedCategory].subcategories;
      if (selectedCategoryName == "Tous" ||
          categories.where((c) => c.name == selectedCategoryName).isEmpty) {
        selectedCategoryName = categories[selectedCategory].name;
      }
    }

    int? currentSubcategoryId;
    if (currentSubCategories.isNotEmpty &&
        selectedSubCategoryIndex >= 0 &&
        selectedSubCategoryIndex < currentSubCategories.length) {
      currentSubcategoryId = currentSubCategories[selectedSubCategoryIndex].id;
    }

    final filteredProducts = productProvider.getFilteredProducts(
      currentCategoryId,
      currentSubcategoryId,
    );

    _precacheVideos(filteredProducts);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Boutique",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: InkWell(
              onTap: () {
                double targetOffset = _categoryScrollController.offset + 250;
                double maxScroll =
                    _categoryScrollController.position.maxScrollExtent;
                if (targetOffset > maxScroll) targetOffset = maxScroll;

                _categoryScrollController.animateTo(
                  targetOffset,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
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
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF6900),
        onRefresh: () async {
          await Future.wait([
            context.read<CategoryProvider>().fetchCategories(),
            context.read<ProductProvider>().fetchProducts(),
          ]);
        },
        child: SafeArea(
          bottom: true,
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
                  maxScroll > 0 && scrollInfo.metrics.extentAfter <= 25;
              FeedVideoManager.instance.setIsAtBottom(isBottom);
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Horizontal Category Selector
                      SizedBox(
                        height: 100,
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF6900),
                                ),
                              )
                            : ListView.builder(
                                controller: _categoryScrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: categories.length,
                                itemBuilder: (context, index) =>
                                    _buildCategoryItem(
                                      categories[index],
                                      index,
                                    ),
                              ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "$selectedCategoryName catégori",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  isSubcategoryShow = !isSubcategoryShow;
                                });
                              },
                              icon: isSubcategoryShow
                                  ? const Icon(Icons.close, color: Colors.black)
                                  : const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.black,
                                    ),
                            ),
                          ],
                        ),
                      ),

                      if (currentSubCategories.isNotEmpty)
                        isSubcategoryShow
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Wrap(
                                  spacing: 10.0,
                                  runSpacing: 10.0,
                                  children: List.generate(
                                    currentSubCategories.length,
                                    (index) => _buildSubCategoryItem(
                                      currentSubCategories[index],
                                      index,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // 2-Column Product Grid with native video playback
                if (isProductsLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6900),
                      ),
                    ),
                  )
                else if (filteredProducts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        "Aucun produit trouvé",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = filteredProducts[index];
                        final double discount =
                            double.tryParse(product.discountPercentage) ?? 0;
                        final bool hasDiscount = discount > 0;
                        final String videoUrl = _resolveProductVideo(product);
                        final String thumbnailUrl = _resolveProductThumbnail(
                          product,
                        );

                        return ShortsProductCard(
                          key: ValueKey('boutique_prod_${product.id}'),
                          keyString: 'boutique_prod_${product.id}',
                          videoUrl: videoUrl,
                          thumbnailUrl: thumbnailUrl,
                          title: product.productName,
                          price: "${product.priceAfterDiscount} FCFA",
                          oldPrice: hasDiscount
                              ? "${product.sellingPrice} FCFA"
                              : null,
                          discount: hasDiscount
                              ? "-${discount.toInt()}%"
                              : null,
                          width: double.infinity,
                          height: double.infinity,
                          onTap: () async {
                            FeedVideoManager.instance.pauseAll();

                            final convertedProducts = filteredProducts.map((p) {
                              final cachedFull = context
                                  .read<ProductProvider>()
                                  .getCachedProduct(p.id);
                              if (cachedFull != null &&
                                  cachedFull.media.isNotEmpty) {
                                return cachedFull;
                              }

                              final pVideo = _resolveProductVideo(p);
                              if (p.media.isEmpty && pVideo.isNotEmpty) {
                                return ProductModel(
                                  id: p.id,
                                  productName: p.productName,
                                  categoryId: p.categoryId,
                                  categoryName: p.categoryName,
                                  subcategoryId: p.subcategoryId,
                                  subcategoryName: p.subcategoryName,
                                  sellingPrice: p.sellingPrice,
                                  discountPercentage: p.discountPercentage,
                                  priceAfterDiscount: p.priceAfterDiscount,
                                  status: p.status,
                                  mainImage: p.mainImage,
                                  media: [
                                    MediaModel(
                                      id: 0,
                                      mediaType: 'video',
                                      mediaUrl: pVideo,
                                      thumbnailUrl: p.mainImage,
                                    ),
                                  ],
                                  actualPrice: p.actualPrice,
                                  deliveryPrice: p.deliveryPrice,
                                  description: p.description,
                                  deliveryMessage: p.deliveryMessage,
                                  variants: p.variants,
                                  stockMode: p.stockMode,
                                  stockQuantity: p.stockQuantity,
                                  unassignedStock: p.unassignedStock,
                                  totalStock: p.totalStock,
                                  noVariant: p.noVariant,
                                  stock: p.stock,
                                );
                              }
                              return p;
                            }).toList();

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailsScreen(
                                  allProducts: convertedProducts,
                                  initialProductIndex: index,
                                ),
                              ),
                            );
                            FeedVideoManager.instance.resume();
                          },
                        );
                      }, childCount: filteredProducts.length),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryModel category, int index) {
    bool isSelected = selectedCategory == index;
    return GestureDetector(
      onTap: () {
        if (selectedCategory == index) return;
        FeedVideoManager.instance.setActiveTab(1);
        FeedVideoManager.instance.clearCategoryCards('boutique_');
        FeedVideoManager.instance.setIsAtBottom(false);
        setState(() {
          selectedCategory = index;
          selectedCategoryName = category.name;
          selectedSubCategoryIndex = -1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          VisibilityDetectorController.instance.notifyNow();
          FeedVideoManager.instance.evaluatePlaybackNow();
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: 70,
              width: 80,
              padding: EdgeInsets.all(
                category.imageUrl.endsWith('.svg') ? 15 : 5,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6900)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: category.imageUrl.endsWith('.svg')
                  ? SvgPicture.asset(
                      category.imageUrl,
                      colorFilter: isSelected
                          ? const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            )
                          : null,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        category.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                            ),
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 80,
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFFFF6900) : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryItem(SubcategoryModel subcategory, int index) {
    bool isSelected = selectedSubCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        FeedVideoManager.instance.setActiveTab(1);
        FeedVideoManager.instance.clearCategoryCards('boutique_');
        FeedVideoManager.instance.setIsAtBottom(false);
        setState(() {
          selectedSubCategoryIndex = isSelected ? -1 : index;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          VisibilityDetectorController.instance.notifyNow();
          FeedVideoManager.instance.evaluatePlaybackNow();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4500) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? null
              : Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          subcategory.name,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? Colors.white : const Color(0xFF34495E),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

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
    this.isAudio = false,
    this.isNetwork = false,
  });
}
