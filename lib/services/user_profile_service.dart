// lib/services/user_profile_service.dart
import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user_model.dart'; // Ensure this path is correct
import 'dart:developer' as developer;

class UserProfileService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUserProfile;
  AppUser? get currentUserProfile => _currentUserProfile;

  bool _isLoadingProfile = true; // Start as true, set to false after first load attempt
  bool get isLoadingProfile => _isLoadingProfile;

  UserProfileService() {
    developer.log("UserProfileService: Initializing and listening to authStateChanges.", name: "UserProfileService");
    _auth.authStateChanges().listen(_onAuthStateChanged);
    // Immediately try to load profile if a user is already logged in
    if (_auth.currentUser != null) {
      _fetchUserProfile(_auth.currentUser!);
    } else {
      _isLoadingProfile = false; // No user, so not loading
       // notifyListeners(); // Not strictly needed here as stream will trigger
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
    // Auth state changed to a new user, fetch their profile
    await _fetchUserProfile(authUser);
  }
  
  // Public method to explicitly refresh/fetch profile if needed elsewhere
  Future<void> fetchAndSetCurrentUserProfile() async {
    User? authUser = _auth.currentUser;
    if (authUser != null) {
      await _fetchUserProfile(authUser);
    } else {
      _currentUserProfile = null;
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<AppUser?> _fetchUserProfile(User authUser) async {
    // Prevent multiple concurrent loads if already loading
    if (_isLoadingProfile && _currentUserProfile != null && _currentUserProfile!.uid == authUser.uid) {
      // Already loading this user's profile, or it's already loaded and matches
      // return _currentUserProfile;
    }

    _isLoadingProfile = true;
    // Notify listeners about loading start only if it's not the initial constructor call
    // where the stream builder might handle the initial loading UI.
    // However, for explicit calls or state changes, it's good.
    if (hasListeners) { // Check if there are listeners before notifying
        notifyListeners();
    }


    try {
      IdTokenResult tokenResult = await authUser.getIdTokenResult(true); // Force refresh claims
      Map<String, dynamic>? claims = tokenResult.claims;

      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection("users").doc(authUser.uid).get();

      if (userDoc.exists) {
        _currentUserProfile = AppUser.fromFirestore(userDoc, authUser, claims);
        developer.log(
            "UserProfileService: Profile loaded for ${authUser.uid}. Role: ${_currentUserProfile?.role}, Dept: ${_currentUserProfile?.department}",
            name: "UserProfileService");
      } else {
        developer.log("UserProfileService: No Firestore document for user ${authUser.uid}. Creating a basic profile from auth data only.", name: "UserProfileService");
        // This might happen if Firestore doc creation failed during signup.
        // Or for users authenticated via methods where Firestore doc isn't immediately created.
        // We should rely on claims primarily for role, but Firestore doc holds more details.
        _currentUserProfile = AppUser(
            uid: authUser.uid,
            email: authUser.email ?? '',
            // Attempt to get username from display name or email part if Firestore doc is missing
            username: claims?['name'] as String? ?? authUser.displayName?.split(' ').first ?? authUser.email?.split('@').first ?? 'User',
            fullName: claims?['name'] as String? ?? authUser.displayName ?? authUser.email?.split('@').first,
            role: claims?['role'] as String? ?? 'user', // Default to 'user' if no claim or doc
            department: claims?['department'] as String?,
            profilePhotoUrl: authUser.photoURL,
            createdAt: Timestamp.now(), // Placeholder if doc doesn't exist
            );
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

  void clearUserProfile() {
    _currentUserProfile = null;
    _isLoadingProfile = false;
    notifyListeners();
    developer.log("UserProfileService: Profile cleared.", name: "UserProfileService");
  }
}