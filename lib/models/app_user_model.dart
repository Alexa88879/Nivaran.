// lib/models/app_user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? username;
  final String? fullName;
  final String? mobileNo;
  final String? employeeId;

  final String? designation;
  final String? department;
  final String? area;
  final String? governmentId;

  final String role;
  final Timestamp? createdAt;
  final String? profilePhotoUrl;
  final List<String>? notificationTokens; // <-- NEWLY ADDED
  final List<String>? subscribedIssueIds; // <-- ADDED from your schema for future use
  final Map<String, bool>? notificationPreferences; // <-- ADDED for future use

  AppUser({
    required this.uid,
    this.email,
    this.username,
    this.fullName,
    this.mobileNo,
    this.employeeId,
    this.designation,
    this.department,
    this.area,
    this.governmentId,
    this.role = 'user',
    this.createdAt,
    this.profilePhotoUrl,
    this.notificationTokens, // <-- ADDED
    this.subscribedIssueIds, // <-- ADDED
    this.notificationPreferences, // <-- ADDED
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, User authUser, Map<String, dynamic>? claims) {
    final data = doc.data() ?? {};
    
    String effectiveRole = claims?['role'] as String? ?? data['role'] as String? ?? 'user';
    String? effectiveDepartment = claims?['department'] as String? ?? data['department'] as String?;

    return AppUser(
      uid: authUser.uid,
      email: authUser.email ?? data['email'] as String?,
      username: data['username'] as String? ?? authUser.displayName?.split(' ').first ?? authUser.email?.split('@').first ?? 'User',
      fullName: data['fullName'] as String? ?? authUser.displayName,
      mobileNo: data['mobileNo'] as String?,
      employeeId: data['employeeId'] as String?,
      designation: data['designation'] as String?,
      department: effectiveDepartment,
      area: data['area'] as String?,
      governmentId: data['governmentId'] as String?,
      role: effectiveRole,
      createdAt: data['createdAt'] as Timestamp?,
      profilePhotoUrl: authUser.photoURL ?? data['profilePhotoUrl'] as String?,
      notificationTokens: data['notificationTokens'] != null ? List<String>.from(data['notificationTokens']) : null, // <-- ADDED
      subscribedIssueIds: data['subscribedIssueIds'] != null ? List<String>.from(data['subscribedIssueIds']) : null, // <-- ADDED
      notificationPreferences: data['notificationPreferences'] != null ? Map<String, bool>.from(data['notificationPreferences']) : null, // <-- ADDED
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      if (email != null) 'email': email,
      if (username != null) 'username': username,
      if (fullName != null) 'fullName': fullName,
      if (mobileNo != null) 'mobileNo': mobileNo,
      if (employeeId != null) 'employeeId': employeeId,
      if (designation != null) 'designation': designation,
      if (department != null) 'department': department,
      if (area != null) 'area': area,
      if (governmentId != null) 'governmentId': governmentId,
      'role': role,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (notificationTokens != null) 'notificationTokens': notificationTokens, // <-- ADDED
      if (subscribedIssueIds != null) 'subscribedIssueIds': subscribedIssueIds, // <-- ADDED
      if (notificationPreferences != null) 'notificationPreferences': notificationPreferences, // <-- ADDED
    };
  }

  bool get isOfficial => role == 'official';
  bool get isAdmin => role == 'admin';
  bool get isPendingOfficial => role == 'official';
}
