import 'package:binetatour/presentation/landing_page/main_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:async'; // Required for Timer or Future.delayed

// Import your main dashboard file here
// import 'package:your_project/screens/main_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start the timer as soon as the screen loads
    _navigateToHome();
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      // pushReplacement removes the splash screen from the navigation stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/splash_screen.jpg"),
            fit: BoxFit.cover, // Ensures the background covers the full screen
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset("assets/icon/splash_icon.svg"),
              const SizedBox(height: 20),
              const Text(
                'Bawane',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE8500A),
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.20,
                ),
              ),
              const Text(
                "Satisfait ou remboursé",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF242424),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.56,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
