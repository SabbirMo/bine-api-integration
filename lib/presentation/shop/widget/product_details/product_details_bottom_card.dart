import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/profile/widget/login_view.dart';
import 'package:binetatour/presentation/shop/vaildation_sceen.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class ProductDetailsBottomCard extends StatefulWidget {
  final ProductModel product;
  final bool isExpanded;
  final bool isLoadingDetails;
  final VoidCallback onToggleExpand;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const ProductDetailsBottomCard({
    super.key,
    required this.product,
    required this.isExpanded,
    required this.isLoadingDetails,
    required this.onToggleExpand,
    this.onPause,
    this.onResume,
  });

  @override
  State<ProductDetailsBottomCard> createState() =>
      _ProductDetailsBottomCardState();
}

class _ProductDetailsBottomCardState extends State<ProductDetailsBottomCard> {
  bool _isBuying = false;

  Future<void> _handleBuyNow() async {
    if (_isBuying) return;

    widget.onPause?.call();
    final token = await TokenStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      if (!mounted) {
        widget.onResume?.call();
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            body: LoginView(
              onLogin: () {
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      );

      final tokenAfter = await TokenStorage.getAccessToken();
      if (tokenAfter == null || tokenAfter.isEmpty) {
        widget.onResume?.call();
        return;
      }
    }

    if (!mounted) {
      widget.onResume?.call();
      return;
    }

    if (widget.product.isOutOfStock) {
      widget.onResume?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Ce produit est en rupture de stock !",
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

    if (mounted) setState(() => _isBuying = true);

    bool success = false;
    try {
      await context
          .read<CartProvider>()
          .addToCart(widget.product, syncImmediately: false)
          .timeout(const Duration(seconds: 6));
      success = true;
    } catch (e) {
      debugPrint("Error adding product to cart: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Impossible de passer la commande : $e",
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBuying = false);
      }
    }

    if (!context.mounted || !success) {
      widget.onResume?.call();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ValidationScreen(),
      ),
    );

    widget.onResume?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Buy Button
            Padding(
              padding: const EdgeInsets.only(right: 25.0),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isBuying ? null : _handleBuyNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6900),
                    disabledBackgroundColor:
                        const Color(0xFFFF6900).withValues(alpha: 0.8),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  label: _isBuying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "J'ACHÈTE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                  icon: _isBuying
                      ? const SizedBox.shrink()
                      : SvgPicture.asset(
                          "assets/icon/cart_black.svg",
                          height: 20,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 2. Price Row
            Row(
              children: [
                Text(
                  "${widget.product.priceAfterDiscount} FCFA",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                if ((double.tryParse(
                          widget.product.discountPercentage
                              .replaceAll('%', '')
                              .trim(),
                        ) ??
                        0) >
                    0) ...[
                  const SizedBox(width: 5),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        "${widget.product.sellingPrice} FCFA",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                          decorationColor:
                              Colors.white.withValues(alpha: 0.7),
                          decorationThickness: 1.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                if (widget.isLoadingDetails)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),

            // 3. Description & Expandable Stock Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Description: ${widget.product.description ?? ''}",
                        maxLines: widget.isExpanded ? 100 : 1,
                        overflow: widget.isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      if (widget.isExpanded) ...[
                        const SizedBox(height: 10),
                        if (widget.product.isProductMode) ...[
                          Text(
                            "Stock: ${widget.product.totalStock} en stock",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            "Variantes & Stock:",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.product.isMixedMode &&
                              widget.product.unassignedStock > 0)
                            Text(
                              "• Sans préférence : ${widget.product.unassignedStock} en stock",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ...widget.product.variants.map(
                            (v) => Text(
                              "• ${v.colorName} (${v.size}) : ${v.stockQuantity} en stock",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (widget.isExpanded &&
                          widget.product.deliveryMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          "Livraison: ${widget.product.deliveryPrice != null ? '${widget.product.deliveryPrice} FCFA' : 'Gratuite'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.product.deliveryMessage!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onToggleExpand,
                  child: widget.isExpanded
                      ? const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 24,
                        )
                      : SvgPicture.asset(
                          "assets/icon/mdi_arrow-down-thin.svg",
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
