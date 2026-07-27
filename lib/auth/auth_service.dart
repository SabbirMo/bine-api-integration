import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? null
        : (defaultTargetPlatform == TargetPlatform.iOS
              ? '74471662195-5jod56lcd4jk039agmo8tmiq9bg0180o.apps.googleusercontent.com'
              : null),
    serverClientId:
        '74471662195-5ac9tsnhgn8emgkjpj3j94lek2a4cdgj.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Force disconnect/sign-out before signing in, so the user is prompted with the account chooser list
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        log("Error disconnecting prior to Google sign-in: $e");
      }

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
      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);
      final String? firebaseIdToken = await userCredential.user?.getIdToken();

      return {
        'idToken': googleAuth.idToken,
        'accessToken': googleAuth.accessToken,
        'firebaseIdToken': firebaseIdToken,
        'name': googleUser.displayName,
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl,
      };
    } catch (e) {
      log("Error signing in with Google: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthCredential credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);
      final String? firebaseIdToken = await userCredential.user?.getIdToken();

      // Apple only returns name and email on first sign-in
      String? displayName =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();
      if (displayName.isEmpty) {
        displayName = userCredential.user?.displayName;
      }
      final String? email = appleCredential.email ?? userCredential.user?.email;

      return {
        'idToken': appleCredential.identityToken,
        'accessToken': appleCredential.authorizationCode,
        'firebaseIdToken': firebaseIdToken,
        'name': displayName,
        'email': email,
        'photoUrl': userCredential.user?.photoURL,
      };
    } catch (e) {
      log("Error signing in with Apple: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      log("Error disconnecting Google Sign In: $e");
    }
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
