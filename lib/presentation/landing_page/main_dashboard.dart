import 'package:binetatour/core/video/feed_video_manager.dart';
import 'package:binetatour/presentation/home/home_page.dart';
import 'package:binetatour/presentation/profile/account/mon_compot_screen.dart';
import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MainDashboard extends StatefulWidget {
  final int initialIndex;
  const MainDashboard({super.key, this.initialIndex = 0});

  static MainDashboardState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainDashboardState>();
  }

  @override
  State<MainDashboard> createState() => MainDashboardState();
}

class MainDashboardState extends State<MainDashboard> {
  late int _currentIndex;
  final GlobalKey<BoutiqueScreenState> _boutiqueKey =
      GlobalKey<BoutiqueScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      const AccueilScreen(),
      BoutiqueScreen(key: _boutiqueKey),
      const MonCompteScreen(),
    ];
  }

  void switchToTab(int index, {int? categoryId}) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
    FeedVideoManager.instance.setActiveTab(index);

    if (index == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (categoryId != null) {
          _boutiqueKey.currentState?.selectCategoryById(categoryId);
        } else {
          _boutiqueKey.currentState?.resetToFirstCategory();
        }
      });
    }

    if (index == 2) {
      FeedVideoManager.instance.pauseAll();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FeedVideoManager.instance.resume();
        VisibilityDetectorController.instance.notifyNow();
        FeedVideoManager.instance.evaluatePlaybackNow();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1 && _currentIndex == 1) {
            _boutiqueKey.currentState?.resetToFirstCategory();
          } else if (index != _currentIndex) {
            switchToTab(index);
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
