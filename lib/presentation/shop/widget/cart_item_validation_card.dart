import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:binetatour/data/models/cart_model.dart';
import 'package:binetatour/data/models/product_model.dart';

class CartItemValidationCard extends StatefulWidget {
  final CartItemModel item;

  /// Called whenever the selected variant changes.
  /// [variantId] is null if no matching variant is found.
  final ValueChanged<int?>? onVariantSelected;

  const CartItemValidationCard({
    super.key,
    required this.item,
    this.onVariantSelected,
  });

  @override
  State<CartItemValidationCard> createState() => _CartItemValidationCardState();
}

class _CartItemValidationCardState extends State<CartItemValidationCard> {
  ProductModel? _productDetails;
  bool _isLoading = true;
  String? _selectedColorCode;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    final details = await context.read<ProductProvider>().fetchProductDetails(
      widget.item.productId,
    );
    if (mounted) {
      setState(() {
        _productDetails = details;
        _isLoading = false;
        // No default selection — user must explicitly choose
        _selectedColorCode = null;
        _selectedSize = null;
      });

      // If product has NO variants, mark as valid automatically (variant_id = 0)
      if (details == null || details.variants.isEmpty) {
        widget.onVariantSelected?.call(0);
      }
    }
  }

  /// Find the variant that matches selected color + size and notify parent.
  void _notifyVariant() {
    if (_productDetails == null) return;

    final variants = _productDetails!.variants;

    // If product has no variants, nothing to select
    if (variants.isEmpty) return;

    final hasColors = variants.any((v) => v.colorCode.isNotEmpty);
    final hasSizes = variants.any((v) => v.size.isNotEmpty);

    // Try to find the best matching variant
    ProductVariantModel? match;

    if (hasColors && hasSizes) {
      // Only valid if both are selected
      if (_selectedColorCode == null || _selectedSize == null) {
        widget.onVariantSelected?.call(null);
        return;
      }
      match = variants.firstWhere(
        (v) => v.colorCode == _selectedColorCode && v.size == _selectedSize,
        orElse: () => variants.first,
      );
    } else if (hasColors) {
      if (_selectedColorCode == null) {
        widget.onVariantSelected?.call(null);
        return;
      }
      match = variants.firstWhere(
        (v) => v.colorCode == _selectedColorCode,
        orElse: () => variants.first,
      );
    } else if (hasSizes) {
      if (_selectedSize == null) {
        widget.onVariantSelected?.call(null);
        return;
      }
      match = variants.firstWhere(
        (v) => v.size == _selectedSize,
        orElse: () => variants.first,
      );
    }

    // If selected variant is out of stock, don't allow ordering
    if (match != null && match.stockQuantity <= 0) {
      widget.onVariantSelected?.call(null);
      return;
    }

    widget.onVariantSelected?.call(match?.id);
  }

  Color _hexToColor(String code) {
    var hexString = code;
    if (hexString.startsWith('#')) {
      hexString = hexString.substring(1);
    }
    if (hexString.length == 6) {
      hexString = 'FF$hexString';
    }
    return Color(int.tryParse(hexString, radix: 16) ?? 0xFF000000);
  }

  Widget _sectionWrapper({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF101828)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _sectionWrapper(
      title: "Article & Quantité",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.item.mainImage ?? "",
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${widget.item.priceAfterDiscount} FCFA",
                      style: const TextStyle(
                        color: Color(0xFFFF6900),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _quantityStepper(widget.item),
            ],
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_productDetails != null &&
              _productDetails!.variants.isNotEmpty)
            _buildVariantsSelection(_productDetails!.variants),
        ],
      ),
    );
  }

  /// Get the selected variant (matching both color and size)
  ProductVariantModel? get _selectedVariant {
    if (_productDetails == null) return null;
    final variants = _productDetails!.variants;
    if (variants.isEmpty) return null;

    for (var v in variants) {
      bool colorMatch = _selectedColorCode == null || v.colorCode == _selectedColorCode;
      bool sizeMatch = _selectedSize == null || v.size == _selectedSize;
      if (colorMatch && sizeMatch) return v;
    }
    return null;
  }

  /// Check if the currently selected variant is out of stock
  bool get _isSelectedVariantOutOfStock {
    final variant = _selectedVariant;
    if (variant == null) return false;
    return variant.stockQuantity <= 0;
  }

  Widget _buildVariantsSelection(List<ProductVariantModel> variants) {
    // Extract unique colors
    final uniqueColors = <String, String>{}; // colorCode -> colorName
    for (var v in variants) {
      if (v.colorCode.isNotEmpty) {
        uniqueColors[v.colorCode] = v.colorName;
      }
    }

    // Filter sizes based on selected color
    // If a color is selected, only show sizes that exist for that color
    final List<ProductVariantModel> filteredVariants;
    if (_selectedColorCode != null) {
      filteredVariants = variants
          .where((v) => v.colorCode == _selectedColorCode)
          .toList();
    } else {
      filteredVariants = variants;
    }

    // Build unique sizes from filtered variants (preserving order)
    final uniqueSizes = <String>[];
    for (var v in filteredVariants) {
      if (v.size.isNotEmpty && !uniqueSizes.contains(v.size)) {
        uniqueSizes.add(v.size);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          if (uniqueColors.isNotEmpty) ...[
            const Text(
              "🎨 Couleur",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: uniqueColors.entries.map((e) {
                return _colorDot(_hexToColor(e.key), e.key, e.value);
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (uniqueSizes.isNotEmpty) ...[
            const Text(
              "Dimensions",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: uniqueSizes.map((size) {
                // Find the stock for this size (with selected color)
                final variantForSize = filteredVariants.firstWhere(
                  (v) => v.size == size,
                  orElse: () => filteredVariants.first,
                );
                return _choiceChip(size, stockQuantity: variantForSize.stockQuantity);
              }).toList(),
            ),
          ],
          // Show out of stock warning if selected variant has 0 stock
          if (_selectedColorCode != null &&
              _selectedSize != null &&
              _isSelectedVariantOutOfStock) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Rupture de stock – Ce produit ne peut pas être commandé",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorDot(Color color, String colorCode, String name) {
    final bool isSelected = _selectedColorCode == colorCode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColorCode = colorCode;
          // Reset size selection when color changes,
          // because available sizes may differ per color
          _selectedSize = null;
        });
        _notifyVariant();
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 15, top: 5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceChip(String text, {required int stockQuantity}) {
    final bool isSelected = _selectedSize == text;
    final bool isOutOfStock = stockQuantity <= 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSize = text;
        });
        _notifyVariant();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isOutOfStock ? Colors.red.shade50 : const Color(0xFFFEF3E7))
              : (isOutOfStock ? Colors.grey.shade100 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isOutOfStock ? Colors.red : const Color(0xFFFF6900))
                : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isOutOfStock
                    ? Colors.grey
                    : (isSelected ? const Color(0xFFFF6900) : Colors.black),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                decoration: isOutOfStock ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isOutOfStock) ...[
              const SizedBox(width: 4),
              Icon(Icons.block, size: 14, color: Colors.red.shade300),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quantityStepper(CartItemModel item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _isSelectedVariantOutOfStock
                ? null
                : () {
                    if (item.quantity > 1) {
                      context.read<CartProvider>().decrement(item.id);
                    }
                  },
            icon: Icon(
              Icons.remove_circle_outline,
              size: 22,
              color: (_isSelectedVariantOutOfStock || item.quantity <= 1)
                  ? Colors.grey.shade400
                  : Colors.black,
            ),
          ),
          Text(
            _isSelectedVariantOutOfStock ? "0" : "${item.quantity}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            onPressed: _isSelectedVariantOutOfStock
                ? null
                : () {
                    if (_productDetails != null &&
                        _productDetails!.variants.isNotEmpty) {
                      final variant = _selectedVariant;

                      if (variant != null) {
                        final maxStock = variant.stockQuantity;
                        if (maxStock <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                "Rupture de stock",
                                textAlign: TextAlign.center,
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(20),
                            ),
                          );
                          return;
                        }
                        if (item.quantity >= maxStock) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Stock disponible : $maxStock",
                                textAlign: TextAlign.center,
                              ),
                              backgroundColor: const Color(0xFFFF6900),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(20),
                            ),
                          );
                          return;
                        }
                      }
                    }
                    context.read<CartProvider>().increment(item.id, context);
                  },
            icon: Icon(
              Icons.add_circle_outline,
              size: 22,
              color: _isSelectedVariantOutOfStock
                  ? Colors.grey.shade400
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
