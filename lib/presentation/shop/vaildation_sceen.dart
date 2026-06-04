import 'package:binetatour/presentation/landing_page/main_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key});

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen> {
  String selectedPayment = "Orange Money";
  int _quantity = 1;
  String _selectedColorName = "Noir"; // Default selection
  final Color _activeOrange = const Color(0xFFFD8C2C);
  String _selectedDimension = "Standard"; // Default selection
  String _selectedDate = "AUJOURD'HUI";
  bool _isAvailableNow = true;
  String _formattedDate = "dd/mm/yyyy";

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      locale: const Locale('fr', 'FR'),
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _formattedDate =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildArticleCard(),
            const SizedBox(height: 12),
            _buildSelectionCard(),
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
      bottomNavigationBar: _buildBottomCTA(),
    );
  }

  // 1. Article & Quantity Section
  Widget _buildArticleCard() {
    return _sectionWrapper(
      title: "Articles & Quantité",
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: const DecorationImage(
                image: AssetImage('assets/images/vaildation.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Galaxy Buds Pro",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "190 000 FCFA",
                  style: TextStyle(
                    color: Color(0xFFFF6900),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _quantityStepper(),
        ],
      ),
    );
  }

  // 2. Color & Dimensions Selection
  Widget _buildSelectionCard() {
    return _sectionWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🎨 Couleur",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _colorDot(Colors.black, "Noir", _quantity),
              _colorDot(Colors.white, "Blanc", _quantity),
              _colorDot(Colors.blueGrey, "Gris", _quantity),
              _colorDot(const Color(0xFFC69C6D), "Beige", _quantity),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Dimensions",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _choiceChip("Standard", _quantity),
              _choiceChip("1m20", _quantity),
              _choiceChip("2m", _quantity),
              _choiceChip("3m", _quantity),
              _choiceChip("Sur-mesure", _quantity),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Form Fields
  Widget _buildUserInfoForm() {
    return _sectionWrapper(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _textField("🤴 Nom", "votre nom")),
              const SizedBox(width: 10),
              Expanded(child: _textField("🤴 Prénom", "votre Prénom")),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _textField("📞 Tél. Principal", "77..")),
              const SizedBox(width: 10),
              Expanded(
                child: _textField("📞 Tél. 2 (Optionnel)", "Secondaire"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _textField("📍 Adresse", "Enter votre adresse"),
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

  Widget _quantityStepper() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Keep the stepper compact
        children: [
          // Decrement Button
          IconButton(
            onPressed: () {
              if (_quantity > 1) {
                setState(() {
                  _quantity--;
                });
              }
            },
            icon: Icon(
              Icons.remove_circle_outline,
              size: 22,
              // Visually disable the button if quantity is 1
              color: _quantity > 1 ? Colors.black : Colors.grey.shade400,
            ),
          ),

          // Display Current Quantity
          Text(
            "$_quantity",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          // Increment Button
          IconButton(
            onPressed: () {
              setState(() {
                _quantity++;
              });
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

  Widget _textField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextField(
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

  Widget _buildBottomCTA() {
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "105 000 FCFA",
                  style: TextStyle(
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Commande réussie")),
                );
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainDashboard()),
                  (route) =>
                      false, // This condition 'false' ensures all previous routes are removed
                );
              },
              child: const Text(
                "JE VALIDE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder helpers for UI consistency
  Widget _colorDot(Color color, String name, int qty) {
    bool isSelected = _selectedColorName == name;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColorName = name;
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(
          right: 15,
          top: 5,
        ), // Added top padding for the badge
        child: Stack(
          clipBehavior:
              Clip.none, // Allows the quantity badge to hang off the edge
          children: [
            // 1. The Main Color Circle with Selection Ring
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(2.5), // Space between ring and dot
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Keep border always present but change color for stability
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
                  // Subtle inner shadow/border to make light colors pop
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
              ),
            ),

            // 2. The Quantity Badge (Only shows when selected)
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
                    color: const Color(0xFFFF4500), // Your _activeOrange
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ), // White ring around badge
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
    bool isSelected = _selectedDimension == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDimension = text;
        });
      },
      child: Padding(
        // Padding ensures the badge doesn't get cut off by parent widgets
        padding: const EdgeInsets.only(top: 6, right: 8, left: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. The Main Chip Body
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

            // 2. The Quantity Badge
            if (isSelected)
              Positioned(
                top: -8, // Adjusted for the rectangular chip shape
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
                        color: Colors.black.withOpacity(0.15),
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
                        height: 1, // Ensures text stays centered
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
