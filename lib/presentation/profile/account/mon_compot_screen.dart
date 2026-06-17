import 'package:binetatour/presentation/profile/widget/profile_view.dart';
import 'package:flutter/material.dart';

import '../widget/login_view.dart';

class MonCompteScreen extends StatefulWidget {
  const MonCompteScreen({super.key});

  @override
  State<MonCompteScreen> createState() => _MonCompteScreenState();
}

class _MonCompteScreenState extends State<MonCompteScreen> {
  // Toggle this to test both UIs
  bool isLoggedIn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mon Compte",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      // Switch between LoginView and ProfileView
      body: isLoggedIn
          ? ProfileView(onLogout: () => setState(() => isLoggedIn = true))
          : LoginView(onLogin: () => setState(() => isLoggedIn = false)),
    );
  }
}
