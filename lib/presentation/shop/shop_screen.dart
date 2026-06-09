import 'package:binetatour/presentation/shop/widget/product_details.dart';
import 'package:binetatour/presentation/shop/widget/shop_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/category_provider.dart';
import 'package:binetatour/data/models/category_model.dart';
import 'package:binetatour/providers/product_provider.dart';

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
    });
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
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
    final List<ShopProductCard> filteredProductCards = filteredProducts.map((
      p,
    ) {
      final double discount = double.tryParse(p.discountPercentage) ?? 0;
      final bool hasDiscount = discount > 0;

      return ShopProductCard(
        title: p.productName,
        price: "${p.priceAfterDiscount} FCFA",
        oldPrice: "${p.sellingPrice} FCFA",
        discount: "-${discount.toInt()}%",
        showDiscountPercentage: hasDiscount,
        showOldPrice: hasDiscount,
        assetThumbnail: p.mainImage ?? '',
        content: p.media
            .map(
              (m) => ProductContent(
                url: m.mediaUrl,
                isVideo: m.mediaType == 'video',
                isImage: m.mediaType == 'image',
                isAudio: m.mediaType == 'audio',
                isNetwork: true,
              ),
            )
            .toList(),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Boutique",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 6.0),
            child: InkWell(
              onTap: () {
                double targetOffset = _categoryScrollController.offset + 250;

                // Ensure we don't try to scroll past the maximum limits
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
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.orange,
        onRefresh: () async {
          context.read<CategoryProvider>().fetchCategories();
          context.read<ProductProvider>().fetchProducts();
          // Wait briefly to allow loading indicators to show.
          await Future.delayed(const Duration(milliseconds: 800));
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
                              color: Colors.orange,
                            ),
                          )
                        : ListView.builder(
                            controller: _categoryScrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: categories.length,
                            itemBuilder: (context, index) =>
                                _buildCategoryItem(categories[index], index),
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
                        Text(
                          "$selectedCategoryName catégori",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              isSubcategoryShow = !isSubcategoryShow;
                            });
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  //sub category show here
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
            // Product Grid
            isProductsLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  )
                : filteredProductCards.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: Text("Aucun produit trouvé")),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailsScreen(
                                  allProducts: filteredProducts,
                                  initialProductIndex: index,
                                ),
                              ),
                            );
                          },
                          child: filteredProductCards[index],
                        );
                      }, childCount: filteredProductCards.length),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryModel category, int index) {
    bool isSelected = selectedCategory == index;
    return GestureDetector(
      onTap: () => setState(() {
        selectedCategory = index;
        selectedCategoryName = category.name;
        selectedSubCategoryIndex = -1;
      }),
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
                color: isSelected ? Colors.orange[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: category.imageUrl.endsWith('.svg')
                  ? SvgPicture.asset(category.imageUrl)
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
            Text(
              category.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.orange[800] : Colors.black,
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
      onTap: () => setState(() {
        selectedSubCategoryIndex = index;
      }),
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
