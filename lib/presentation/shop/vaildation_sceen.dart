import 'package:binetatour/presentation/landing_page/main_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/providers/store_settings_provider.dart';
import 'package:binetatour/presentation/shop/widget/cart_item_validation_card.dart';
import 'package:binetatour/presentation/shop/widget/payment_status_dialog.dart';
import 'package:binetatour/core/widgets/fireworks_overlay.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';
import 'package:binetatour/core/utils/date_utils.dart';
import 'package:binetatour/core/utils/external_intent_launcher.dart';

class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  String selectedPayment = "Orange Money";
  String _selectedDate = "AUJOURD'HUI";
  bool _isAvailableNow = true;
  String _formattedDate = "dd/mm/yyyy";
  bool _isSubmitting = false;

  /// Maps cartItemId -> selected variantId (null means no variant selected or "Sans préférence")
  final Map<int, int?> _selectedVariantIds = {};

  /// Maps cartItemId -> whether the item is valid for order
  final Map<int, bool> _validItems = {};

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreSettingsProvider>().fetchStoreSettings();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('fr', 'FR'),
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    setState(() => _formattedDate = DateFormat('dd/MM/yyyy').format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final items = cartProvider.cart?.items ?? [];
        if (items.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
              title: const Text(
                "Validation",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.remove_shopping_cart_outlined,
                    size: 70,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Votre panier est vide",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6900),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      "Continuer mes achats",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
            title: const Text(
              "Validation",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: CartItemValidationCard(
                      key: ValueKey(item.id),
                      item: item,
                      onSelectionChanged: (isValid, variantId) {
                        setState(() {
                          _validItems[item.id] = isValid;
                          _selectedVariantIds[item.id] = variantId;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildUserInfoForm(),
                const SizedBox(height: 12),
                _buildDeliverySchedule(),
                const SizedBox(height: 12),
                _buildNoteField(),
                const SizedBox(height: 12),
                _buildPaymentMethods(),
                const SizedBox(height: 20),
                _buildFooterInfo(),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomCTA(cartProvider),
        );
      },
    );
  }

  // 3. Form Fields
  Widget _buildUserInfoForm() {
    return _sectionWrapper(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _textField(
                  "🤴 Nom",
                  "votre nom",
                  controller: _nameController,
                  maxLength: 15,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  "🤴 Prénom",
                  "votre Prénom",
                  controller: _surnameController,
                  maxLength: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _textField(
                  "📞 Tél. Principal",
                  "77..",
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  maxLength: 13,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  "📞 Tél. 2 (Optionnel)",
                  "Secondaire",
                  controller: _phone2Controller,
                  keyboardType: TextInputType.number,
                  maxLength: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _textField(
            "📍 Adresse",
            "Enter votre adresse",
            controller: _addressController,
            maxLength: 35,
          ),
        ],
      ),
    );
  }

  // 4. Payment Methods
  Widget _buildPaymentMethods() {
    return _sectionWrapper(
      child: Column(
        children: [
          _paymentTile("Wave", "assets/images/wave.png"),
          const SizedBox(height: 8),
          _paymentTile("Orange Money", "assets/images/money.png"),
          const SizedBox(height: 8),
          _paymentTile("Liquide À La Livraison", "assets/images/truck.png"),
        ],
      ),
    );
  }

  // Utility Widgets
  Widget _sectionWrapper({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFF101828)),
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

  Widget _textField(
    String label,
    String hint, {
    TextEditingController? controller,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: [
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: InputDecoration(
            counterText: "",
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _paymentTile(String title, String asset) {
    // Check if this specific tile is selected
    // We use a simplified key for the logic to match your 'Liquide' case
    String selectionKey = title.contains("Liquide") ? "Liquide" : title;
    bool isSelected = selectedPayment == selectionKey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          selectedPayment = selectionKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          // Light orange background when selected
          color: isSelected ? const Color(0xFFFFF1EB) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6900) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Radio Icon
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFFFF6900) : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.black87,
                ),
              ),
            ),
            // Provider Logo
            Image.asset(
              asset,
              height: 28,
              width: 28,
              fit: BoxFit.contain,
              // Fallback if image is missing during dev
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.payment, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCTA(CartProvider cartProvider) {
    String totalAmount = cartProvider.cart?.total.isNotEmpty == true
        ? cartProvider.cart!.total
        : "0";
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3E7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "$totalAmount FCFA",
                        style: const TextStyle(
                          color: Color(0xFFFF6900),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                SafeArea(
                  top: false,
                  bottom: bottomInset == 0,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6900),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              // ── Validate: every item must have a valid selection ──
                              final cartItems = cartProvider.cart?.items ?? [];
                              final List<String> missingVariantProducts = [];

                              for (final cartItem in cartItems) {
                                final isValid =
                                    _validItems[cartItem.id] ?? false;
                                if (!isValid) {
                                  missingVariantProducts.add(
                                    cartItem.productName,
                                  );
                                }
                              }

                              if (missingVariantProducts.isNotEmpty &&
                                  context.mounted) {
                                final names = missingVariantProducts.join(', ');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFFFF4500),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "$names : Veuillez choisir une option (variante ou sans préférence)",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }

                              if (cartItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Votre panier est vide."),
                                    backgroundColor: Color(0xFFFF6900),
                                  ),
                                );
                                return;
                              }

                              setState(() => _isSubmitting = true);

                              try {
                                String deliveryDate = "";
                                if (_selectedDate == "AUJOURD'HUI") {
                                  deliveryDate = AppDateUtils.toApiDate(
                                    DateTime.now(),
                                  );
                                } else if (_selectedDate == "DEMAIN") {
                                  deliveryDate = AppDateUtils.toApiDate(
                                    DateTime.now().add(
                                      const Duration(days: 1),
                                    ),
                                  );
                                } else {
                                  final parsed = AppDateUtils.tryParseDateTime(
                                    _formattedDate,
                                  );
                                  deliveryDate = AppDateUtils.toApiDate(parsed);
                                }

                                final String deliveryTimeStr =
                                    AppDateUtils.toApiTime(
                                      _timeController.text,
                                    );

                                // Build items list with product_id and conditional variant_id
                                final items = cartItems.map((cartItem) {
                                  final variantId =
                                      _selectedVariantIds[cartItem.id];
                                  final itemMap = <String, dynamic>{
                                    "product_id": cartItem.productId,
                                    "quantity": cartItem.quantity,
                                  };
                                  if (variantId != null && variantId > 0) {
                                    itemMap["variant_id"] = variantId;
                                  }
                                  return itemMap;
                                }).toList();

                                String orderPaymentMethod;
                                String payProvider;
                                if (selectedPayment == "Wave") {
                                  orderPaymentMethod = "wave";
                                  payProvider = "wave";
                                } else if (selectedPayment == "Liquide") {
                                  orderPaymentMethod = "cash_on_delivery";
                                  payProvider = "cash_on_delivery";
                                } else {
                                  // Orange Money
                                  orderPaymentMethod = "orange_money";
                                  payProvider = "orange";
                                }

                                // Step 1 – Create the order
                                final int? orderId = await orderProvider
                                    .createOrder(
                                      items: items,
                                      customerName: _nameController.text,
                                      customerSurname: _surnameController.text,
                                      customerPhone: _phoneController.text,
                                      customerPhone2: _phone2Controller.text,
                                      customerAddress: _addressController.text,
                                      deliveryDate: deliveryDate,
                                      deliveryTime: deliveryTimeStr,
                                      deliveryTimeEnd: deliveryTimeStr,
                                      deliveryNote: _noteController.text,
                                      deliveryFee: "0.00",
                                      paymentMethod: orderPaymentMethod,
                                    );

                                if (orderId == null) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          orderProvider.errorMessage ??
                                              "Erreur lors de la commande",
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // Step 2 – Handle Cash on Delivery vs Online Payment
                                if (payProvider == "cash_on_delivery") {
                                  await cartProvider.clearServerCart();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Commande confirmée"),
                                      ),
                                    );
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MainDashboard(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                  return;
                                }

                                // Step 3 – Initiate online payment (Orange Money / Wave)
                                final payResponse = await orderProvider
                                    .payOrder(
                                      orderId: orderId,
                                      provider: payProvider,
                                    );

                                if (!context.mounted) return;

                                if (payResponse == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        orderProvider.errorMessage ??
                                            "Erreur lors du paiement",
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final qrData =
                                    payResponse['qr'] as Map<String, dynamic>?;
                                final dataMap =
                                    payResponse['data']
                                        as Map<String, dynamic>?;

                                // Extract transaction ID
                                final dynamic rawTxId =
                                    payResponse['transaction_id'] ??
                                    qrData?['metadata']?['transaction_id'] ??
                                    payResponse['metadata']?['transaction_id'] ??
                                    dataMap?['transaction_id'] ??
                                    payResponse['id'];
                                final int transactionId = rawTxId is int
                                    ? rawTxId
                                    : int.tryParse(
                                            rawTxId?.toString() ?? '0',
                                          ) ??
                                          0;

                                // Extract deep link
                                String? deepLink =
                                    payResponse['payment_url']?.toString() ??
                                    payResponse['paymentUrl']?.toString() ??
                                    payResponse['redirect_url']?.toString() ??
                                    payResponse['redirectUrl']?.toString() ??
                                    payResponse['wave_launch_url']
                                        ?.toString() ??
                                    payResponse['deep_link']?.toString() ??
                                    payResponse['deepLink']?.toString() ??
                                    payResponse['launch_url']?.toString() ??
                                    payResponse['url']?.toString() ??
                                    qrData?['payment_url']?.toString() ??
                                    qrData?['paymentUrl']?.toString() ??
                                    qrData?['deepLink']?.toString() ??
                                    qrData?['wave_launch_url']?.toString() ??
                                    qrData?['launch_url']?.toString() ??
                                    qrData?['url']?.toString() ??
                                    dataMap?['payment_url']?.toString() ??
                                    dataMap?['paymentUrl']?.toString() ??
                                    dataMap?['wave_launch_url']?.toString() ??
                                    dataMap?['deepLink']?.toString() ??
                                    dataMap?['url']?.toString();

                                final String? qrCode =
                                    qrData?['qrCode']?.toString() ??
                                    payResponse['qrCode']?.toString() ??
                                    dataMap?['qrCode']?.toString();
                                final String? message =
                                    payResponse['message']?.toString() ??
                                    qrData?['message']?.toString();
                                final dynamic val =
                                    qrData?['validity'] ??
                                    payResponse['validity'] ??
                                    dataMap?['validity'];
                                final int validity = val is int
                                    ? val
                                    : int.tryParse(val?.toString() ?? '300') ??
                                          300;
                                final Map<String, dynamic>? deepLinksMap =
                                    (qrData?['deepLinks']
                                        as Map<String, dynamic>?) ??
                                    (payResponse['deepLinks']
                                        as Map<String, dynamic>?);

                                // For Wave, optionally attempt auto-launching app
                                if (selectedPayment == "Wave" &&
                                    deepLink != null &&
                                    deepLink.isNotEmpty) {
                                  ExternalIntentLauncher.launchPaymentDeepLink(
                                    deepLinkUrl: deepLink,
                                    context: context,
                                  );
                                }

                                // Step 4 – Show Payment Status Popup with live polling
                                if (transactionId > 0) {
                                  PaymentStatusDialog.show(
                                    context: context,
                                    transactionId: transactionId,
                                    providerName: selectedPayment,
                                    qrCodeBase64: qrCode,
                                    deepLink: deepLink,
                                    deepLinks: deepLinksMap,
                                    message: message,
                                    validitySeconds: validity,
                                    onPaymentSuccess: (statusModel) async {
                                      await cartProvider.clearServerCart();
                                      if (context.mounted) {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            backgroundColor: Color(0xFF2E7D32),
                                            content: Text(
                                              "Paiement réussi ! Commande confirmée.",
                                            ),
                                          ),
                                        );
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const MainDashboard(),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    },
                                  );
                                } else {
                                  // Fallback if no transactionId
                                  await cartProvider.clearServerCart();
                                  if (context.mounted) {
                                    FireworksOverlay.show(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Color(0xFF2E7D32),
                                        content: Text(
                                          "Commande confirmée avec succès !",
                                        ),
                                      ),
                                    );
                                    await Future.delayed(
                                      const Duration(milliseconds: 1800),
                                    );
                                    if (context.mounted) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const MainDashboard(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        orderProvider.errorMessage ??
                                            "Erreur lors de la validation: $e",
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isSubmitting = false);
                                }
                              }
                            },
                      child: _isSubmitting
                          ? const CoolShimmer(
                              child: CoolShimmerBone.circle(size: 20),
                            )
                          : const Text(
                              "JE VALIDE",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliverySchedule() {
    return _sectionWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Section
          const Row(
            children: [
              Text("🗓️ ", style: TextStyle(fontSize: 16)),
              Text(
                "Date de livraison",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScheduleButton(
                  "AUJOURD'HUI",
                  _selectedDate == "AUJOURD'HUI",
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildScheduleButton(
                  "DEMAIN",
                  _selectedDate == "DEMAIN",
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildScheduleButton(
                  "AUTRE DATE",
                  _selectedDate == "AUTRE DATE",
                ),
              ),
            ],
          ),

          if (_selectedDate == "AUTRE DATE") ...[
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () => _selectDate(context), // Function to show Calendar
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xffF85000),
                    width: 1,
                  ), // Dark blue border
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formattedDate,
                      style: const TextStyle(
                        color: Color(0xFFF85000),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Time Section
          const Row(
            children: [
              Text("⏱️ ", style: TextStyle(fontSize: 16)),
              Text(
                "Heure de livraison",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildScheduleButton(
                  "JE SUIS DISPONIBLE",
                  _isAvailableNow,
                  isTimeButton: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _timeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  // Apply the auto-formatter here
                  inputFormatters: [TimeTextInputFormatter()],
                  decoration: InputDecoration(
                    hintText: "00h : 00",
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF6900),
                      ), // App Orange
                    ),
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleButton(
    String text,
    bool isSelected, {
    bool isTimeButton = false,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isTimeButton) {
            _isAvailableNow = !_isAvailableNow;
          } else {
            _selectedDate = text;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6900) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6900) : Colors.grey.shade400,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return _sectionWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text("📝 ", style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  "Note particulière pour le livreur",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3, // Set the height of the note area
            textInputAction: TextInputAction.done,
            onEditingComplete: () {
              FocusScope.of(context).unfocus();
            },
            decoration: InputDecoration(
              hintText: "Note particulière...",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              // Custom border to match the reference image
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFF2E3E4C),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6900),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Consumer<StoreSettingsProvider>(
      builder: (context, provider, child) {
        final heading = provider.storeSettings?.deliveryHeading;
        final message =
            provider.storeSettings?.deliveryMessage?.isNotEmpty == true
            ? provider.storeSettings!.deliveryMessage!
            : "";

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (heading != null && heading.trim().isNotEmpty) ...[
              Text(
                heading,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15.62,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                height: 2.08,
              ),
            ),
          ],
        );
      },
    );
  }
}

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Handle backspace when formatted text ends with "h : "
    if (oldValue.text.length > newValue.text.length) {
      if (oldValue.text.endsWith("h : ") || oldValue.text.endsWith("h :")) {
        if (text.length == 2) {
          text = text.substring(0, 1);
        } else if (text.length == 1) {
          text = "";
        }
      }
    }

    if (text.isEmpty) {
      return const TextEditingValue(
        text: "",
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Limit to max 4 digits
    if (text.length > 4) {
      text = text.substring(0, 4);
    }

    String formatted = "";

    if (text.length <= 2) {
      int hh = int.tryParse(text) ?? 0;
      if (hh > 24) {
        text = "24";
      }
      formatted = "${text}h : ";
    } else {
      String hoursPart = text.substring(0, 2);
      int hh = int.tryParse(hoursPart) ?? 0;
      if (hh > 24) {
        hoursPart = "24";
      }

      String minutesPart = text.substring(2);
      int mm = int.tryParse(minutesPart) ?? 0;
      if (minutesPart.length == 2 && mm > 59) {
        minutesPart = "59";
      }

      formatted = "${hoursPart}h : $minutesPart";
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
