import 'package:binetatour/presentation/landing_page/main_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/presentation/shop/widget/cart_item_validation_card.dart';

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

  /// Maps cartItemId -> selected variantId (null means not yet selected)
  final Map<int, int?> _selectedVariantIds = {};

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

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
                      item: item,
                      onVariantSelected: (variantId) {
                        setState(() {
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  "🤴 Prénom",
                  "votre Prénom",
                  controller: _surnameController,
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textField(
                  "📞 Tél. 2 (Optionnel)",
                  "Secondaire",
                  controller: _phone2Controller,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _textField(
            "📍 Adresse",
            "Enter votre adresse",
            controller: _addressController,
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
          decoration: InputDecoration(
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
    String totalAmount = cartProvider.cart?.total.toStringAsFixed(2) ?? "0.00";
    return Container(
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6900),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final orderProvider = Provider.of<OrderProvider>(
                  context,
                  listen: false,
                );

                // ── Validate: every item with variants must have a variant selected ──
                final cartItems = cartProvider.cart?.items ?? [];
                final List<String> missingVariantProducts = [];

                for (final cartItem in cartItems) {
                  final selectedVariant = _selectedVariantIds[cartItem.id];
                  // If the map has no entry yet OR the entry is null, variant not selected
                  if (!_selectedVariantIds.containsKey(cartItem.id) ||
                      selectedVariant == null) {
                    missingVariantProducts.add(cartItem.productName);
                  }
                }

                if (missingVariantProducts.isNotEmpty && context.mounted) {
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
                              "$names : couleur ou taille non sélectionnée",
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

                String deliveryDate = "";
                if (_selectedDate == "AUJOURD'HUI") {
                  deliveryDate = DateFormat(
                    'yyyy-MM-dd',
                  ).format(DateTime.now());
                } else if (_selectedDate == "DEMAIN") {
                  deliveryDate = DateFormat(
                    'yyyy-MM-dd',
                  ).format(DateTime.now().add(const Duration(days: 1)));
                } else {
                  try {
                    final parts = _formattedDate.split('/');
                    deliveryDate = "${parts[2]}-${parts[1]}-${parts[0]}";
                  } catch (e) {
                    deliveryDate = DateFormat(
                      'yyyy-MM-dd',
                    ).format(DateTime.now());
                  }
                }

                String deliveryTimeStr = "06:25:27.291Z"; // Default fallback
                if (!_isAvailableNow && _timeController.text.isNotEmpty) {
                  deliveryTimeStr =
                      "${_timeController.text.replaceAll('h :', ':').replaceAll(' ', '')}:00.000Z";
                }

                // Build items list with selected variant_id
                final items = cartItems.map((cartItem) {
                  return {
                    "variant_id": _selectedVariantIds[cartItem.id] ?? 0,
                    "quantity": cartItem.quantity,
                  };
                }).toList();

                String apiPaymentMethod = "orange_money";
                if (selectedPayment == "Wave") {
                  apiPaymentMethod = "wave";
                } else if (selectedPayment == "Liquide") {
                  apiPaymentMethod = "cash_on_delivery";
                } else if (selectedPayment == "Orange Money") {
                  apiPaymentMethod = "orange_money";
                }

                final success = await orderProvider.createOrder(
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
                  paymentMethod: apiPaymentMethod,
                );

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Commande réussie")),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainDashboard()),
                    (route) => false,
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        orderProvider.errorMessage ??
                            "Erreur lors de la commande",
                      ),
                    ),
                  );
                }
              },
              child: Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  return orderProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "JE VALIDE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        );
                },
              ),
            ),
          ),
        ],
      ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildScheduleButton(
                "AUJOURD'HUI",
                _selectedDate == "AUJOURD'HUI",
              ),
              const SizedBox(width: 8),
              _buildScheduleButton("DEMAIN", _selectedDate == "DEMAIN"),
              const SizedBox(width: 8),
              _buildScheduleButton("AUTRE DATE", _selectedDate == "AUTRE DATE"),
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
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              "Enregistrer L'heure De Votre Disponibilité",
              style: TextStyle(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6900) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6900) : Colors.grey.shade400,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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
              Text(
                "Note particulière pour le livreur",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3, // Set the height of the note area
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

  Widget _buildFooterInfo() => const Text(
    "Livraison gratuite a Dakar vous y croyez 🤩si vous êtes a Mbour ; thies ; Saly dans tout les régions du Sénégal . resté joignable le livreur vous appellera pour organiser la livraison avec vous 📞",
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.black,
      fontSize: 15.62,
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w500,
      height: 2.08,
    ),
  );
}

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    ); // Numbers only
    String formatted = "";

    // Handle typing logic
    if (text.isNotEmpty) {
      if (text.length <= 2) {
        // User types: 12 -> 12h :
        formatted = "${text}h : ";
      } else if (text.length <= 4) {
        // User types: 1234 -> 12h : 34
        formatted = "${text.substring(0, 2)}h : ${text.substring(2)}";
      } else {
        // Prevent typing more than 4 digits
        formatted = "${text.substring(0, 2)}h : ${text.substring(2, 4)}";
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
