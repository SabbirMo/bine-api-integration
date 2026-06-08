import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:binetatour/data/models/cart_model.dart';
import 'package:binetatour/data/models/product_model.dart';

class CartItemValidationCard extends StatefulWidget {
  final CartItemModel item;

  const CartItemValidationCard({super.key, required this.item});

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

        // Optionally set default selection to the first available variant
        if (details != null && details.variants.isNotEmpty) {
          _selectedColorCode = details.variants.first.colorCode;
          _selectedSize = details.variants.first.size;
        }
      });
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

  Widget _buildVariantsSelection(List<ProductVariantModel> variants) {
    // Extract unique colors and sizes
    final uniqueColors = <String, String>{}; // colorCode -> colorName
    final uniqueSizes = <String>{};

    for (var v in variants) {
      if (v.colorCode.isNotEmpty) {
        uniqueColors[v.colorCode] = v.colorName;
      }
      if (v.size.isNotEmpty) {
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
                return _colorDot(
                  _hexToColor(e.key),
                  e.key,
                  e.value,
                  widget.item.quantity,
                );
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
                return _choiceChip(size, widget.item.quantity);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorDot(Color color, String colorCode, String name, int qty) {
    bool isSelected = _selectedColorCode == colorCode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColorCode = colorCode;
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 15, top: 5),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
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
            if (isSelected)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4500),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      qty.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceChip(String text, int qty) {
    bool isSelected = _selectedSize == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSize = text;
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 8, left: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFEF3E7) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF6900)
                      : Colors.grey.shade300,
                  width: 1.2,
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF6900) : Colors.black,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4500),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      qty.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
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
            onPressed: () {
              if (item.quantity > 1) {
                context.read<CartProvider>().decrement(item.id);
              }
            },
            icon: Icon(
              Icons.remove_circle_outline,
              size: 22,
              color: item.quantity > 1 ? Colors.black : Colors.grey.shade400,
            ),
          ),
          Text(
            "${item.quantity}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            onPressed: () {
              context.read<CartProvider>().increment(item.id);
            },
            icon: const Icon(
              Icons.add_circle_outline,
              size: 22,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
