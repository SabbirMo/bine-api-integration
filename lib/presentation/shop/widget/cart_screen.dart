import 'package:binetatour/presentation/common/widgets/product_thumbnail_or_video_frame.dart';
import 'package:binetatour/presentation/shop/vaildation_sceen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/data/models/cart_model.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class CartBottomSheet extends StatefulWidget {
  const CartBottomSheet({super.key});

  @override
  State<CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends State<CartBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = context.read<CartProvider>();
      final hasData = cartProvider.cart != null;
      cartProvider.fetchCart(showLoading: !hasData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (cartProvider.isLoading && cartProvider.cart == null) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: const Column(
              children: [
                SizedBox(height: 24),
                CoolShimmerBone.pill(width: 40, height: 4),
                SizedBox(height: 16),
                Expanded(
                  child: ShimmerList.cart(itemCount: 4),
                ),
              ],
            ),
          );
        }

        final cart = cartProvider.cart;
        final items = cart?.items ?? [];
        String totalDisplay = cart?.total.isNotEmpty == true
            ? cart!.total
            : "0";

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Builder(
              builder: (context) {
                return SafeArea(
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          children: [
                            // 1. Left Back Arrow
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),

                            // 2. Centered Title
                            const Expanded(
                              child: Text(
                                "MON PANIER",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // 3. Right Cancel Button
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: RefreshIndicator(
                          color: const Color(0xFFFF6900),
                          onRefresh: () async {
                            try {
                              await context.read<CartProvider>().fetchCart().timeout(
                                const Duration(seconds: 8),
                              );
                            } catch (e) {
                              debugPrint("Cart refresh error or timeout: $e");
                            }
                          },
                          child: items.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 150),
                                    Center(
                                      child: Text("Votre panier est vide"),
                                    ),
                                  ],
                                )
                              : ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  children: [
                                    ...items.map(
                                      (item) => _buildCartItem(item),
                                    ),
                                    const SizedBox(height: 30),

                                    // Total Box
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E6),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: const Color(0xFFFFD1A1),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "Total",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "$totalDisplay FCFA",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFFF6900),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // Bottom Buttons
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Divider(),
                            const SizedBox(height: 10),
                            _buildSecondaryButton(
                              "Continuer Mes Achats",
                              Icons.add,
                            ),
                            const SizedBox(height: 12),
                            _buildPrimaryButton(context, "JE VALIDE"),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartItem(CartItemModel item) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          ProductThumbnailOrVideoFrame(
            imageUrl: item.effectiveThumbnailUrl,
            videoUrl: item.effectiveVideoUrl,
            productId: item.productId,
            width: 80,
            height: 80,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${item.effectivePrice.isNotEmpty ? item.effectivePrice : (item.priceAfterDiscount.isNotEmpty ? item.priceAfterDiscount : item.sellingPrice)} FCFA",
                  style: const TextStyle(
                    color: Color(0xFFFF6900),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((item.colorName != null && item.colorName!.isNotEmpty) ||
                    (item.size != null && item.size!.isNotEmpty)) ...[
                  const SizedBox(height: 2),
                  Text(
                    "${item.colorName ?? ''} ${item.size != null && item.size!.isNotEmpty ? '(${item.size})' : ''}"
                        .trim(),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 8),
                // Counter UI
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _counterBtn(Icons.remove, () {
                        Provider.of<CartProvider>(
                          context,
                          listen: false,
                        ).decrement(item.id);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "${item.quantity}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _counterBtn(Icons.add, () {
                        Provider.of<CartProvider>(
                          context,
                          listen: false,
                        ).increment(item.id, context);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false).remove(item.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback action) {
    return InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, String label) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: () {
          final cartProvider = context.read<CartProvider>();
          final items = cartProvider.cart?.items ?? [];
          if (items.isEmpty) {
            showTopSnackBar(
              Overlay.of(context),
              Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6900),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    "Votre panier est vide !",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ValidationScreen()),
          );
        },
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, IconData icon) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF3F4F6),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: () => Navigator.pop(context),
        icon: Icon(icon, color: Colors.black),
        label: Text(label, style: const TextStyle(color: Colors.black)),
      ),
    );
  }
}
