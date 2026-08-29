import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

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
    final stopwatch = Stopwatch()..start();
    try {
      // 1. Google sign-in dialog (opens instantly)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final t1 = stopwatch.elapsedMilliseconds;

      // User cancelled
      if (googleUser == null) {
        log("User cancel sign in (after ${t1}ms)");
        return null;
      }
      log("Google sign-in account chosen in ${t1}ms: ${googleUser.email}");

      // 2. Fetch authentication tokens from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final t2 = stopwatch.elapsedMilliseconds;

      // 3. Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // 4. Firebase login
      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);
      final t3 = stopwatch.elapsedMilliseconds;
      log("Firebase sign-in completed in ${t3 - t2}ms (total: ${t3}ms)");

      // Use cached token (false) to avoid redundant network refresh
      final String? firebaseIdToken = await userCredential.user?.getIdToken(
        false,
      );
      final totalTime = stopwatch.elapsedMilliseconds;
      log(
        "Firebase ID token obtained in ${totalTime - t3}ms (total sign-in time: ${totalTime}ms)",
      );

      return {
        'idToken': googleAuth.idToken,
        'accessToken': googleAuth.accessToken,
        'firebaseIdToken': firebaseIdToken,
        'name': googleUser.displayName,
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl,
      };
    } catch (e, stack) {
      debugPrint(
        "Error signing in with Google after ${stopwatch.elapsedMilliseconds}ms: $e",
      );
      debugPrint("Stacktrace: $stack");
      rethrow;
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
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        log("User canceled Apple sign in");
        return null;
      }
      log("Apple Auth Authorization Exception: ${e.message}");
      rethrow;
    } catch (e) {
      log("Error signing in with Apple: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      log("Error during Google signOut: $e");
    }
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      log("Error during Firebase signOut: $e");
    }
  }
}
