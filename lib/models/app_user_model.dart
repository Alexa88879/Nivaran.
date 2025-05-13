// lib/models/app_user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for User type hint in fromFirestore

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
  });

  // Corrected factory constructor signature
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, User authUser, Map<String, dynamic>? claims) {
    final data = doc.data() ?? {};
    
    String effectiveRole = claims?['role'] as String? ?? data['role'] as String? ?? 'user';
    String? effectiveDepartment = claims?['department'] as String? ?? data['department'] as String?;

    return AppUser(
      uid: authUser.uid, // Use authUser.uid for consistency
      email: authUser.email ?? data['email'] as String?, // Prioritize authUser email
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
      profilePhotoUrl: authUser.photoURL ?? data['profilePhotoUrl'] as String?, // Prioritize authUser photoURL
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
    };
  }

  bool get isOfficial => role == 'official';
  bool get isAdmin => role == 'admin';
  bool get isPendingOfficial => role == 'official'; // <<--- ADDED GETTER
}