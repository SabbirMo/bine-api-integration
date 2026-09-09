import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/profile/widget/login_view.dart';
import 'package:binetatour/presentation/shop/widget/cart_screen.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductDetailsActionSidebar extends StatefulWidget {
  final ProductModel product;
  final String currentMediaUrl;
  final bool isExpanded;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const ProductDetailsActionSidebar({
    super.key,
    required this.product,
    required this.currentMediaUrl,
    required this.isExpanded,
    this.onPause,
    this.onResume,
  });

  @override
  State<ProductDetailsActionSidebar> createState() =>
      _ProductDetailsActionSidebarState();
}

class _ProductDetailsActionSidebarState
    extends State<ProductDetailsActionSidebar> {
  bool _isAddingToCart = false;

  Widget _buildActionIcon(IconData icon, String label) {
    return Column(
      children: [
        Text(
          String.fromCharCode(icon.codePoint),
          style: TextStyle(
            inherit: false,
            fontSize: 28,
            fontFamily: icon.fontFamily,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAddToCart() async {
    if (_isAddingToCart) return;

    widget.onPause?.call();
    final token = await TokenStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      if (!mounted) return;
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

    if (mounted) setState(() => _isAddingToCart = true);

    try {
      context.read<ProductProvider>().seedProductCache(widget.product);
      await context
          .read<CartProvider>()
          .addToCart(widget.product, syncImmediately: false)
          .timeout(const Duration(seconds: 6));

      if (!mounted) {
        widget.onResume?.call();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Produit ajouté au panier avec succès !",
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

      if (mounted) {
        setState(() => _isAddingToCart = false);
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const CartBottomSheet(),
      );
      widget.onResume?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
      if (!mounted) return;

      final checkToken = await TokenStorage.getAccessToken();
      if (checkToken == null || checkToken.isEmpty) {
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
        widget.onResume?.call();
        return;
      }

      widget.onResume?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Impossible d'ajouter au panier : $e",
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
  }

  Future<void> _handleWhatsApp() async {
    String productUrl = widget.currentMediaUrl;
    if (productUrl.isEmpty && widget.product.mainImage != null) {
      productUrl = widget.product.mainImage!;
    }

    final String shareText = productUrl.isNotEmpty
        ? "Bonjour, je souhaite commander ce produit : $productUrl.\nVoici mes informations de livraison :\n\n* Adresse ?\n* Heure souhaitée ?\n* Numéro téléphone ?"
        : "Bonjour, je souhaite commander ce produit.\nVoici mes informations de livraison :\n\n* Adresse ?\n* Heure souhaitée ?\n* Numéro téléphone ?";

    final String phoneNumber = dotenv.env["WHATSAPP_PHONE"] ?? " ";

    final whatsappAppUrl = Uri.parse(
      "whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(shareText)}",
    );
    final whatsappWebUrl = Uri.parse(
      "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(shareText)}",
    );

    bool launched = false;
    try {
      launched = await launchUrl(
        whatsappAppUrl,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          whatsappAppUrl,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          whatsappWebUrl,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "WhatsApp n'est pas installé sur cet appareil et impossible d'ouvrir le navigateur.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleShare() {
    String shareText = widget.currentMediaUrl;
    if (shareText.isEmpty && widget.product.mainImage != null) {
      shareText = widget.product.mainImage!;
    }

    if (shareText.isNotEmpty) {
      // ignore: deprecated_member_use
      Share.share(shareText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      right: 4,
      bottom: (widget.isExpanded ? 210 : 160) + bottomInset,
      child: RepaintBoundary(
        child: Column(
          children: [
            // 1. Add to Cart Button
            CupertinoButton(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              pressedOpacity: 0.65,
              onPressed: _handleAddToCart,
              child: _isAddingToCart
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                        radius: 11,
                      ),
                    )
                  : _buildActionIcon(Icons.add, "Panier"),
            ),
            const SizedBox(height: 14),

            // 2. WhatsApp Button
            CupertinoButton(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              pressedOpacity: 0.65,
              onPressed: _handleWhatsApp,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white),
                    ),
                    child: SvgPicture.asset(
                      "assets/icon/ic_baseline-whatsapp.svg",
                      height: 25,
                      width: 25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Whatsapp",
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Share Button
            CupertinoButton(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              pressedOpacity: 0.65,
              onPressed: _handleShare,
              child: Column(
                children: [
                  SvgPicture.asset(
                    "assets/icon/mdi_share.svg",
                    // ignore: deprecated_member_use
                    color: Colors.white,
                    height: 25,
                    width: 25,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Partager",
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
