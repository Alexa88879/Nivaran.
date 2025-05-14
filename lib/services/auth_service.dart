// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart'; // For accessing UserProfileService
import 'user_profile_service.dart';     // Import UserProfileService
import 'package:flutter/material.dart';   // For BuildContext
import 'dart:developer' as developer; // For logging

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Login with Email and Password
  Future<void> signInWithEmail(BuildContext context, String email, String password) async {
    // No try-catch here; let the caller handle FirebaseAuthException
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    // After successful Firebase Auth, trigger profile loading
    if (context.mounted) {
      await Provider.of<UserProfileService>(context, listen: false).fetchAndSetCurrentUserProfile();
    }
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    try {
   
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        developer.log('Google sign-in cancelled by user.', name: "AuthService");
        return null; // User cancelled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // After successful Firebase Auth, trigger profile loading
      if (userCredential.user != null && context.mounted) {
        await Provider.of<UserProfileService>(context, listen: false).fetchAndSetCurrentUserProfile();
      }
      return userCredential;
    } catch (e,s) {
      developer.log('Google sign-in error: $e', name: "AuthService", stackTrace: s);
      // Optionally sign out the Firebase user if Google auth succeeded but subsequent steps failed
      if (_auth.currentUser != null) {
        if (context.mounted) await signOut(context); // Check mounted before async call
      }
      return null;
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      if (context.mounted) {
        Provider.of<UserProfileService>(context, listen: false).clearUserProfile();
      }
      developer.log("User signed out successfully.", name: "AuthService");
    } catch (e) {
      developer.log("Error during sign out: $e", name: "AuthService");
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}