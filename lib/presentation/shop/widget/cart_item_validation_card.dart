import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:binetatour/data/models/cart_model.dart';
import 'package:binetatour/data/models/product_model.dart';

class CartItemValidationCard extends StatefulWidget {
  final CartItemModel item;

  /// Called whenever the selected variant changes.
  /// [variantId] is null if no matching variant is found or if "Sans préférence" / product mode is active.
  final ValueChanged<int?>? onVariantSelected;

  /// Enhanced callback providing both validity flag and variantId
  final void Function(bool isValid, int? variantId)? onSelectionChanged;

  const CartItemValidationCard({
    super.key,
    required this.item,
    this.onVariantSelected,
    this.onSelectionChanged,
  });

  @override
  State<CartItemValidationCard> createState() => _CartItemValidationCardState();
}

class _CartItemValidationCardState extends State<CartItemValidationCard> {
  ProductModel? _productDetails;
  bool _isLoading = true;
  String? _selectedColorCode;
  String? _selectedSize;
  bool _isUnassignedSelected = false; // "Sans préférence" for mixed mode

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
      String? initialColor = widget.item.colorCode;
      String? initialSize = widget.item.size;

      if (initialColor != null && initialColor.isEmpty) initialColor = null;
      if (initialSize != null && initialSize.isEmpty) initialSize = null;

      setState(() {
        _productDetails = details;
        _isLoading = false;
        _selectedColorCode = initialColor;
        _selectedSize = initialSize;
        _isUnassignedSelected = false;
      });

      if (details == null ||
          details.isProductMode ||
          details.variants.isEmpty) {
        // Product mode: automatically valid, no variant_id
        _notify(isValid: true, variantId: null);
      } else {
        // Variant mode or mixed mode: user needs to make a selection
        _notifyVariant();
      }
      _clampQuantityToMaxStock();
    }
  }

  void _clampQuantityToMaxStock() {
    if (_productDetails == null) return;
    final maxStock = _maxAvailableStock;
    if (maxStock > 0 && widget.item.quantity > maxStock) {
      context.read<CartProvider>().updateQuantity(widget.item.id, maxStock);
    }
  }

  void _notify({required bool isValid, required int? variantId}) {
    widget.onVariantSelected?.call(variantId);
    widget.onSelectionChanged?.call(isValid, variantId);
  }

  /// Find the variant that matches selected color + size and notify parent.
  void _notifyVariant() {
    if (_productDetails == null) return;

    if (_productDetails!.isProductMode || _productDetails!.variants.isEmpty) {
      _notify(isValid: true, variantId: null);
      return;
    }

    if (_isUnassignedSelected) {
      // "Sans préférence" chosen in mixed mode
      final hasStock = _productDetails!.unassignedStock > 0;
      _notify(isValid: hasStock, variantId: null);
      return;
    }

    final variants = _productDetails!.variants;
    final hasColors = variants.any((v) => v.colorCode.isNotEmpty);
    final hasSizes = variants.any((v) => v.size.isNotEmpty);

    ProductVariantModel? match;

    if (hasColors && hasSizes) {
      if (_selectedColorCode == null || _selectedSize == null) {
        _notify(isValid: false, variantId: null);
        return;
      }
      try {
        match = variants.firstWhere(
          (v) => v.colorCode == _selectedColorCode && v.size == _selectedSize,
        );
      } catch (_) {
        match = null;
      }
    } else if (hasColors) {
      if (_selectedColorCode == null) {
        _notify(isValid: false, variantId: null);
        return;
      }
      try {
        match = variants.firstWhere((v) => v.colorCode == _selectedColorCode);
      } catch (_) {
        match = null;
      }
    } else if (hasSizes) {
      if (_selectedSize == null) {
        _notify(isValid: false, variantId: null);
        return;
      }
      try {
        match = variants.firstWhere((v) => v.size == _selectedSize);
      } catch (_) {
        match = null;
      }
    }

    if (match != null && match.stockQuantity > 0) {
      _notify(isValid: true, variantId: match.id);
    } else {
      _notify(isValid: false, variantId: match?.id);
    }
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

  String _formatPrice(double price) {
    if (price % 1 == 0) {
      final formatter = NumberFormat('#,###', 'fr_FR');
      return formatter.format(price.toInt()).replaceAll(',', ' ');
    } else {
      final formatter = NumberFormat('#,##0.00', 'fr_FR');
      return formatter.format(price).replaceAll(',', ' ');
    }
  }

  bool _hasVariantsOrOptions(ProductModel product) {
    if (product.isMixedMode && product.unassignedStock > 0) return true;
    if (product.isProductMode || product.variants.isEmpty) return false;
    final hasColors = product.variants.any((v) => v.colorCode.isNotEmpty);
    final hasSizes = product.variants.any((v) => v.size.isNotEmpty);
    return hasColors || hasSizes;
  }

  Widget _cardWrapper({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF101828), width: 1.0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVariantsOrOptions =
        _productDetails != null && _hasVariantsOrOptions(_productDetails!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CARD 1: Articles & Quantité ──
        _cardWrapper(
          title: "Articles & Quantité",
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  widget.item.mainImage ?? "",
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${_formatPrice(widget.item.priceAfterDiscount)} FCFA",
                      style: const TextStyle(
                        color: Color(0xFFFF6900),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _quantityStepper(widget.item),
            ],
          ),
        ),

        // ── Loading indicator while fetching product variants ──
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: _cardWrapper(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF6900),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── CARD 2: Couleur & Dimensions (Separate Card) ──
        if (!_isLoading && hasVariantsOrOptions)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: _cardWrapper(
              child: _buildStockAndVariantsSection(_productDetails!),
            ),
          ),
      ],
    );
  }

  /// Get the selected variant (matching both color and size)
  ProductVariantModel? get _selectedVariant {
    if (_productDetails == null || _isUnassignedSelected) return null;
    final variants = _productDetails!.variants;
    if (variants.isEmpty) return null;

    final hasColors = variants.any((v) => v.colorCode.isNotEmpty);
    final hasSizes = variants.any((v) => v.size.isNotEmpty);

    if (hasColors && _selectedColorCode == null) return null;
    if (hasSizes && _selectedSize == null) return null;

    for (var v in variants) {
      bool colorMatch =
          _selectedColorCode == null || v.colorCode == _selectedColorCode;
      bool sizeMatch = _selectedSize == null || v.size == _selectedSize;
      if (colorMatch && sizeMatch) return v;
    }
    return null;
  }

  /// Check if the currently selected choice is out of stock
  bool get _isCurrentChoiceOutOfStock {
    if (_productDetails == null) return false;
    if (_isUnassignedSelected) {
      return _productDetails!.unassignedStock <= 0;
    }
    final variant = _selectedVariant;
    if (variant != null) {
      return variant.stockQuantity <= 0;
    }
    if (_productDetails!.isProductMode || _productDetails!.variants.isEmpty) {
      return _productDetails!.totalStock <= 0;
    }
    return false;
  }

  /// Get maximum stock for current selection
  int get _maxAvailableStock {
    if (_productDetails == null) return 999;
    if (_isUnassignedSelected) {
      return _productDetails!.unassignedStock;
    }
    final variant = _selectedVariant;
    if (variant != null) {
      return variant.stockQuantity;
    }
    if (_productDetails!.isProductMode || _productDetails!.variants.isEmpty) {
      return _productDetails!.totalStock > 0
          ? _productDetails!.totalStock
          : _productDetails!.stockQuantity;
    }

    final variants = _productDetails!.variants;
    final hasColors = variants.any((v) => v.colorCode.isNotEmpty);
    final hasSizes = variants.any((v) => v.size.isNotEmpty);

    if (_selectedColorCode != null && hasSizes && _selectedSize == null) {
      final colorVariants = variants.where(
        (v) => v.colorCode == _selectedColorCode,
      );
      if (colorVariants.isNotEmpty) {
        return colorVariants.fold<int>(
          0,
          (max, v) => v.stockQuantity > max ? v.stockQuantity : max,
        );
      }
    }

    if (_selectedSize != null && hasColors && _selectedColorCode == null) {
      final sizeVariants = variants.where((v) => v.size == _selectedSize);
      if (sizeVariants.isNotEmpty) {
        return sizeVariants.fold<int>(
          0,
          (max, v) => v.stockQuantity > max ? v.stockQuantity : max,
        );
      }
    }

    return _productDetails!.totalStock;
  }

  Widget _buildStockAndVariantsSection(ProductModel product) {
    final variants = product.variants;
    final bool showUnassignedOption =
        product.isMixedMode && product.unassignedStock > 0;

    // Extract unique colors: colorCode -> colorName
    final uniqueColors = <String, String>{};
    for (var v in variants) {
      if (v.colorCode.isNotEmpty) {
        String name = v.colorName.trim();
        uniqueColors[v.colorCode] = name;
      }
    }

    // Filter sizes based on selected color
    final List<ProductVariantModel> filteredVariants;
    if (_selectedColorCode != null) {
      filteredVariants = variants
          .where((v) => v.colorCode == _selectedColorCode)
          .toList();
    } else {
      filteredVariants = variants;
    }

    // Build unique sizes
    final uniqueSizes = <String>[];
    for (var v in filteredVariants) {
      if (v.size.isNotEmpty && !uniqueSizes.contains(v.size)) {
        uniqueSizes.add(v.size);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mixed Mode "Sans préférence" option
        if (showUnassignedOption) ...[
          _buildUnassignedOption(product.unassignedStock),
          const SizedBox(height: 14),
        ],

        // ── Couleur Section ──
        if (uniqueColors.isNotEmpty) ...[
          const Text(
            "🎨 Couleur",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: uniqueColors.entries.map((e) {
              return _colorDot(_hexToColor(e.key), e.key, e.value);
            }).toList(),
          ),
          if (uniqueSizes.isNotEmpty) const SizedBox(height: 18),
        ],

        // ── Dimensions Section ──
        if (uniqueSizes.isNotEmpty) ...[
          const Text(
            "Dimensions",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: uniqueSizes.map((size) {
              final variantForSize = filteredVariants.firstWhere(
                (v) => v.size == size,
                orElse: () => filteredVariants.first,
              );
              return _choiceChip(
                size,
                stockQuantity: variantForSize.stockQuantity,
              );
            }).toList(),
          ),
        ],

        // ── Out of stock banner ──
        if (_isCurrentChoiceOutOfStock) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 18,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Rupture de stock – Cette variante ne peut pas être commandée",
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
    );
  }

  Widget _buildUnassignedOption(int unassignedStock) {
    final bool isSelected = _isUnassignedSelected;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isUnassignedSelected = !_isUnassignedSelected;
          if (_isUnassignedSelected) {
            _selectedColorCode = null;
            _selectedSize = null;
          }
        });
        _notifyVariant();
        if (_isUnassignedSelected) {
          _clampQuantityToMaxStock();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3E6) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6900) : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF6900) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Sans préférence (Toutes couleurs)",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6900)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "$unassignedStock en stock",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color, String colorCode, String name) {
    final bool isSelected =
        _selectedColorCode == colorCode && !_isUnassignedSelected;
    final bool isLightColor = color == Colors.white ||
        color.toARGB32() == 0xFFFFFFFF ||
        color.computeLuminance() > 0.85;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isUnassignedSelected = false; // Deselect "Sans préférence"
          _selectedColorCode = colorCode;

          // Check if current _selectedSize is valid for this new color
          if (_productDetails != null && _selectedSize != null) {
            final matchingVariants = _productDetails!.variants.where(
              (v) => v.colorCode == colorCode && v.size == _selectedSize,
            );
            if (matchingVariants.isEmpty) {
              final availableSizes = _productDetails!.variants
                  .where((v) => v.colorCode == colorCode && v.size.isNotEmpty)
                  .map((v) => v.size)
                  .toSet()
                  .toList();
              if (availableSizes.length == 1) {
                _selectedSize = availableSizes.first;
              } else {
                _selectedSize = null;
              }
            }
          } else if (_productDetails != null) {
            final availableSizes = _productDetails!.variants
                .where((v) => v.colorCode == colorCode && v.size.isNotEmpty)
                .map((v) => v.size)
                .toSet()
                .toList();
            if (availableSizes.length == 1) {
              _selectedSize = availableSizes.first;
            }
          }
        });
        _notifyVariant();
        _clampQuantityToMaxStock();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            padding: EdgeInsets.all(isSelected ? 3.0 : 0.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFFF6900) : Colors.transparent,
                width: 2.0,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLightColor
                      ? const Color(0xFFD0D5DD)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
            ),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF101828)
                    : const Color(0xFF475467),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _choiceChip(String text, {required int stockQuantity}) {
    final bool isSelected = _selectedSize == text && !_isUnassignedSelected;
    final bool isOutOfStock = stockQuantity <= 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isUnassignedSelected = false; // Deselect "Sans préférence"
          _selectedSize = text;
        });
        _notifyVariant();
        _clampQuantityToMaxStock();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isOutOfStock ? Colors.red.shade50 : const Color(0xFFFFECE5))
              : (isOutOfStock ? Colors.grey.shade100 : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isOutOfStock ? Colors.red : const Color(0xFFFF6900))
                : (isOutOfStock ? Colors.grey.shade300 : const Color(0xFF6B7280)),
            width: isSelected ? 1.5 : 1.1,
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
                    : (isSelected
                        ? const Color(0xFFFF6900)
                        : const Color(0xFF374151)),
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
    final bool isBlocked = _isCurrentChoiceOutOfStock;
    final int maxStock = _maxAvailableStock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF101828), width: 1.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: (isBlocked || item.quantity <= 1)
                ? null
                : () {
                    context.read<CartProvider>().decrement(item.id);
                  },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.remove_circle_outline,
                size: 22,
                color: (isBlocked || item.quantity <= 1)
                    ? Colors.grey.shade400
                    : const Color(0xFF101828),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Text(
              isBlocked ? "0" : "${item.quantity}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF101828),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: isBlocked
                ? null
                : () {
                    if (isBlocked || maxStock <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            "Ce produit est en rupture de stock !",
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
                    context.read<CartProvider>().increment(item.id, context);
                  },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.add_circle_outline,
                size: 22,
                color:
                    isBlocked ? Colors.grey.shade400 : const Color(0xFF101828),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

