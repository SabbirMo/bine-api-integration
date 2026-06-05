import 'package:binetatour/presentation/shop/widget/product_details.dart';
import 'package:binetatour/presentation/shop/widget/shop_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/category_provider.dart';
import 'package:binetatour/data/models/category_model.dart';
import 'package:binetatour/providers/product_provider.dart';

class BoutiqueScreen extends StatefulWidget {
  const BoutiqueScreen({super.key});

  @override
  State<BoutiqueScreen> createState() => _BoutiqueScreenState();
}

class _BoutiqueScreenState extends State<BoutiqueScreen> {
  int selectedCategory = 0;
  late ScrollController _categoryScrollController;
  String selectedCategoryName = "Tous";

  bool isSubcategoryShow = true;

  int selectedSubCategoryIndex = -1;

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Category Selector
          SizedBox(
            height: 100,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // Pushes text to left and icon to right
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
                  constraints:
                      const BoxConstraints(), // Removes default padding to keep it clean
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.close_rounded, // Rounded cross icon
                    color: Colors.black, // Clean dark grey/black color
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
                      spacing: 10.0, // Horizontal gap between chips
                      runSpacing: 10.0, // Vertical gap between lines
                      children: List.generate(
                        currentSubCategories.length,
                        (index) => _buildSubCategoryItem(
                          currentSubCategories[index],
                          index,
                        ),
                      ),
                    ),
                  )
                : SizedBox(),
          SizedBox(height: 10),
          // Product Grid
          Expanded(
            child: isProductsLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : filteredProductCards.isEmpty
                ? const Center(child: Text("Aucun produit trouvé"))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: filteredProductCards.length,
                      itemBuilder: (context, index) {
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
                      },
                    ),
                  ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4500) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? null
              : Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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

final List<ShopProductCard> sportsProductList = [
  ShopProductCard(
    title: "Ballon de Football",
    price: "185 000 FCFA",
    assetThumbnail: "assets/images/balonde.jpg",
    showDiscountPercentage: true,
    showOldPrice: true,
    content: [
      ProductContent(
        url: "https://www.pexels.com/download/video/6573622/",
        isVideo: true,
        isImage: false,
      ),
      ProductContent(
        url:
            "https://images.pexels.com/photos/46798/the-ball-stadion-football-the-pitch-46798.jpeg",
        isVideo: false,
        isImage: true,
      ),
      ProductContent(
        url:
            "https://images.pexels.com/photos/34247678/pexels-photo-34247678.jpeg",
        isVideo: false,
        isImage: true,
      ),
    ],
  ),
  ShopProductCard(
    title: "iPhone 15 Pro",
    price: "850 000 FCFA",
    assetThumbnail: "assets/icon/teenis.jpg",
    showDiscountPercentage: false,
    showOldPrice: false,
    content: [
      ProductContent(
        url:
            "https://images.pexels.com/photos/18525574/pexels-photo-18525574.jpeg",
        isVideo: false,
        isImage: true,
      ),
      ProductContent(
        url: "https://www.pexels.com/download/video/6217343/",
        isVideo: true,
        isImage: false,
      ),
      ProductContent(
        url:
            "https://images.pexels.com/photos/16479766/pexels-photo-16479766.jpeg",
        isVideo: false,
        isImage: true,
      ),
    ],
  ),
  ShopProductCard(
    title: "Canapé Moderne",
    price: "450 000 FCFA",
    assetThumbnail: "assets/icon/teenis.jpg",
    showDiscountPercentage: false,
    showOldPrice: false,
    content: [
      ProductContent(
        url: "https://www.pexels.com/download/video/36108265/",
        isVideo: true,
        isImage: false,
      ),
      ProductContent(
        url:
            "https://images.pexels.com/photos/1866149/pexels-photo-1866149.jpeg",
        isVideo: false,
        isImage: true,
      ),
      ProductContent(
        url: "https://www.pexels.com/download/video/36108280/",
        isVideo: true,
        isImage: false,
      ),
    ],
  ),
  ShopProductCard(
    title: "Canapé Lounge",
    price: "185 000 FCFA",
    discount: "-11%",
    oldPrice: "210 000 FCFA",
    showDiscountPercentage: true,
    showOldPrice: true,
    assetThumbnail: "assets/images/lounge.jpg",
    content: [
      ProductContent(
        url: "https://images.pexels.com/photos/276583/pexels-photo-276583.jpeg",
        isVideo: false,
        isImage: true,
      ),
      ProductContent(
        url:
            "https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg",
        isVideo: false,
        isImage: true,
      ),
      ProductContent(
        url: "https://www.pexels.com/download/video/36108265/",
        isVideo: true,
        isImage: false,
      ),
    ],
  ),
  ShopProductCard(
    title: "Coffee Fort Blend",
    price: "850 000 FCFA",
    showDiscountPercentage: false,
    showOldPrice: false,
    assetThumbnail: "assets/images/fort_blend.jpg",
    content: [
      ProductContent(
        url: "https://www.pexels.com/download/video/17422066/",
        isVideo: true,
        isImage: false,
      ),
      ProductContent(
        url: "https://images.pexels.com/photos/312418/pexels-photo-312418.jpeg",
        isVideo: false,
        isImage: true,
      ),
    ],
  ),
  ShopProductCard(
    title: "Canapé Moderne",
    price: "450 000 FCFA",
    discount: "-11%",
    oldPrice: "500 000 FCFA",
    showDiscountPercentage: true,
    showOldPrice: true,
    assetThumbnail: "assets/images/lounge.jpg",
    content: [
      ProductContent(
        url:
            "https://images.pexels.com/photos/15491800/pexels-photo-15491800.jpeg",
        isVideo: false,
        isImage: true,
      ),
      ProductContent(
        url: "https://www.pexels.com/download/video/11429925/",
        isVideo: true,
        isImage: false,
      ),
      ProductContent(
        url:
            "https://images.pexels.com/photos/6489121/pexels-photo-6489121.jpeg",
        isVideo: false,
        isImage: true,
      ),
    ],
  ),
];
