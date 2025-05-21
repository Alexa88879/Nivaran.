// lib/services/user_profile_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // For token type
import '../models/app_user_model.dart';
import 'dart:developer' as developer;

class UserProfileService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance; // For getting token

  AppUser? _currentUserProfile;
  AppUser? get currentUserProfile => _currentUserProfile;

  bool _isLoadingProfile = true;
  bool get isLoadingProfile => _isLoadingProfile;

  UserProfileService() {
    developer.log("UserProfileService: Initializing and listening to authStateChanges.", name: "UserProfileService");
    _auth.authStateChanges().listen(_onAuthStateChanged);
    if (_auth.currentUser != null) {
      _fetchUserProfile(_auth.currentUser!);
    } else {
      _isLoadingProfile = false;
    }
  }

  Future<void> _onAuthStateChanged(User? authUser) async {
    developer.log("UserProfileService: Auth state changed. User: ${authUser?.uid}", name: "UserProfileService");
    if (authUser == null) {
      _currentUserProfile = null;
      _isLoadingProfile = false;
      notifyListeners();
      return;
    }
    await _fetchUserProfile(authUser);
    await _updateUserFCMToken(authUser.uid); // Update token on auth change
  }
  
  Future<void> fetchAndSetCurrentUserProfile() async {
    User? authUser = _auth.currentUser;
    if (authUser != null) {
      await _fetchUserProfile(authUser);
      await _updateUserFCMToken(authUser.uid); // Also update token on explicit fetch
    } else {
      _currentUserProfile = null;
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<AppUser?> _fetchUserProfile(User authUser) async {
    if (_isLoadingProfile && _currentUserProfile?.uid == authUser.uid) {
      // Already loading or loaded for this user
      // return _currentUserProfile; // Can cause issues if called rapidly
    }

    _isLoadingProfile = true;
    if (hasListeners) {
        notifyListeners();
    }

    try {
      IdTokenResult tokenResult = await authUser.getIdTokenResult(true);
      Map<String, dynamic>? claims = tokenResult.claims;

      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection("users").doc(authUser.uid).get();

      if (userDoc.exists) {
        _currentUserProfile = AppUser.fromFirestore(userDoc, authUser, claims);
        developer.log(
            "UserProfileService: Profile loaded for ${authUser.uid}. Role: ${_currentUserProfile?.role}, Dept: ${_currentUserProfile?.department}",
            name: "UserProfileService");
      } else {
        developer.log("UserProfileService: No Firestore document for user ${authUser.uid}. Creating basic profile.", name: "UserProfileService");
        _currentUserProfile = AppUser(
            uid: authUser.uid,
            email: authUser.email ?? '',
            username: claims?['name'] as String? ?? authUser.displayName?.split(' ').first ?? authUser.email?.split('@').first ?? 'User',
            fullName: claims?['name'] as String? ?? authUser.displayName ?? authUser.email?.split('@').first,
            role: claims?['role'] as String? ?? 'user',
            department: claims?['department'] as String?,
            profilePhotoUrl: authUser.photoURL,
            createdAt: Timestamp.now(),
            );
        // Save this basic profile if it doesn't exist
        await _firestore.collection("users").doc(authUser.uid).set(_currentUserProfile!.toMap(), SetOptions(merge: true));
      }
    } catch (e, s) {
      developer.log("UserProfileService: Error fetching user profile for ${authUser.uid}: $e", name: "UserProfileService", error:e, stackTrace:s);
      _currentUserProfile = null; 
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
    return _currentUserProfile;
  }

  // --- NEW METHOD to update FCM token ---
  Future<void> _updateUserFCMToken(String userId) async {
    if (userId.isEmpty) return;

    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        developer.log("UserProfileService: Updating FCM token for user $userId: $token", name: "UserProfileService");
        final userRef = _firestore.collection('users').doc(userId);
        await userRef.set({
          'notificationTokens': FieldValue.arrayUnion([token]) // Add token if not present
        }, SetOptions(merge: true)); // Merge to avoid overwriting other fields

        // Optional: Clean up old tokens if necessary, but arrayUnion handles duplicates.
        // If a user can have multiple devices, arrayUnion is fine.
        // If only one token per user, you might want to overwrite the array: 'notificationTokens': [token]
      }
    } catch (e) {
      developer.log("UserProfileService: Error updating FCM token for $userId: $e", name: "UserProfileService");
    }
  }

  void clearUserProfile() {
    _currentUserProfile = null;
    _isLoadingProfile = false;
    // TODO: Optionally, remove the FCM token from the user's document on explicit logout,
    // or handle it server-side if a token becomes invalid. For now, tokens will remain.
    notifyListeners();
    developer.log("UserProfileService: Profile cleared.", name: "UserProfileService");
  }
}
