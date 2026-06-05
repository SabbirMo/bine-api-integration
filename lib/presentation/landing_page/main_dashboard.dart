import 'package:binetatour/presentation/home/home_page.dart';
import 'package:binetatour/presentation/profile/account/mon_compot_screen.dart';
import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:flutter/material.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AccueilScreen(),
    const BoutiqueScreen(),
    const MonCompteScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),

        // 1. Force the icons to stay Orange regardless of selection
        selectedIconTheme: IconThemeData(color: Colors.orange[800]),
        unselectedIconTheme: IconThemeData(color: Colors.orange[800]),

        // 2. Set the labels to Black
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,

        // 3. Ensure the font style follows the color
        selectedLabelStyle: const TextStyle(color: Colors.black, fontSize: 12),
        unselectedLabelStyle: const TextStyle(
          color: Colors.black,
          fontSize: 12,
        ),

        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: "Boutique"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Compte"),
        ],
      ),
    );
  }
}
