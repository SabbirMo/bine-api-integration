import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '74471662195-5ac9tsnhgn8emgkjpj3j94lek2a4cdgj.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
    ],
  );

  Future<String?> signInWithGoogle() async {
    try {
      //google login
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      //user cancel
      if (googleUser == null) {
        log("User cancel sign in");
        return null;
      }

      // google sign authentication data
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      //create firebase crenditial
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      //firebase login
      await _firebaseAuth.signInWithCredential(credential);

      return googleAuth.idToken;
    } catch (e) {
      log("Error signing in with Google: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
