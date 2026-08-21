import 'package:binetatour/core/video/feed_video_manager.dart';
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
        onTap: (index) {
          if (index != _currentIndex) {
            FeedVideoManager.instance.pauseAll();
            setState(() => _currentIndex = index);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FeedVideoManager.instance.resume();
            });
          }
        },
        selectedItemColor: const Color(0xffFF6900),
        unselectedItemColor: const Color(0xFF7E848C),
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: "Boutique",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: "Compte",
          ),
        ],
      ),
    );
  }
}
