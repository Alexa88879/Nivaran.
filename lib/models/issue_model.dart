// lib/models/issue_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum VoteType { upvote, downvote }

class LocationModel {
  final double latitude;
  final double longitude;
  final String address;

  LocationModel({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String? ?? 'Address not available',
    );
  }

   Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
}

class Issue {
  final String id;
  final String description; // Final English description
  final String category;
  final String? urgency;
  final List<String>? tags;
  final String imageUrl;
  final Timestamp timestamp;
  final LocationModel location;
  final String userId;
  final String username;
  final String status;
  final String? assignedDepartment;
  final int upvotes;
  final int downvotes;
  final Map<String, VoteType> voters;
  final int commentsCount;
  final int affectedUsersCount;
  final List<String> affectedUserIds;
  final String? originalSpokenText; // <-- NEW FIELD
  final String? userInputLanguage; // <-- NEW FIELD
  final String? aiRiskAnalysis; // Added from schema doc
  final Timestamp? resolutionTimestamp; // Added from schema doc
  final String? lastStatusUpdateBy; // Added from schema doc
  final Timestamp? lastStatusUpdateAt; // Added from schema doc
  final bool isUnresolved; // Added from schema doc


  Issue({
    required this.id,
    required this.description,
    required this.category,
    this.urgency,
    this.tags,
    required this.imageUrl,
    required this.timestamp,
    required this.location,
    required this.userId,
    required this.username,
    required this.status,
    this.assignedDepartment,
    required this.upvotes,
    required this.downvotes,
    required this.voters,
    required this.commentsCount,
    this.affectedUsersCount = 1,
    List<String>? affectedUserIds,
    this.originalSpokenText, // <-- ADDED TO CONSTRUCTOR
    this.userInputLanguage, // <-- ADDED TO CONSTRUCTOR
    this.aiRiskAnalysis,
    this.resolutionTimestamp,
    this.lastStatusUpdateBy,
    this.lastStatusUpdateAt,
    this.isUnresolved = true,
  }) : affectedUserIds = affectedUserIds ?? [];


  factory Issue.fromFirestore(Map<String, dynamic> data, String documentId) {
    Map<String, VoteType> votersMap = {};
    if (data['voters'] != null && data['voters'] is Map) {
      (data['voters'] as Map<dynamic, dynamic>).forEach((key, value) {
        if (key is String && value is String) {
          if (value == 'upvote') {
            votersMap[key] = VoteType.upvote;
          } else if (value == 'downvote') {
            votersMap[key] = VoteType.downvote;
          }
        }
      });
    }

    return Issue(
      id: documentId,
      description: data['description'] as String? ?? 'No description',
      category: data['category'] as String? ?? 'Uncategorized',
      urgency: data['urgency'] as String?,
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      imageUrl: data['imageUrl'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      location: LocationModel.fromMap(data['location'] as Map<String, dynamic>? ?? {}),
      userId: data['userId'] as String? ?? 'Unknown UserID',
      username: data['username'] as String? ?? 'Anonymous',
      status: data['status'] as String? ?? 'Reported',
      assignedDepartment: data['assignedDepartment'] as String?,
      upvotes: data['upvotes'] as int? ?? 0,
      downvotes: data['downvotes'] as int? ?? 0,
      voters: votersMap,
      commentsCount: data['commentsCount'] as int? ?? 0,
      affectedUsersCount: data['affectedUsersCount'] as int? ?? 1,
      affectedUserIds: List<String>.from(data['affectedUserIds'] ?? []),
      originalSpokenText: data['originalSpokenText'] as String?, // <-- ADDED MAPPING
      userInputLanguage: data['userInputLanguage'] as String?, // <-- ADDED MAPPING
      aiRiskAnalysis: data['aiRiskAnalysis'] as String?,
      resolutionTimestamp: data['resolutionTimestamp'] as Timestamp?,
      lastStatusUpdateBy: data['lastStatusUpdateBy'] as String?,
      lastStatusUpdateAt: data['lastStatusUpdateAt'] as Timestamp?,
      isUnresolved: data['isUnresolved'] as bool? ?? (data['status'] != 'Resolved' && data['status'] != 'Rejected'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'category': category,
      if (urgency != null) 'urgency': urgency,
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
      'location': location.toMap(),
      'userId': userId,
      'username': username,
      'status': status,
      if (assignedDepartment != null) 'assignedDepartment': assignedDepartment,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'voters': voters.map((key, value) => MapEntry(key, value.name)),
      'commentsCount': commentsCount,
      'affectedUsersCount': affectedUsersCount,
      'affectedUserIds': affectedUserIds,
      if (originalSpokenText != null) 'originalSpokenText': originalSpokenText, // <-- ADDED TO MAP
      if (userInputLanguage != null) 'userInputLanguage': userInputLanguage, // <-- ADDED TO MAP
      if (aiRiskAnalysis != null) 'aiRiskAnalysis': aiRiskAnalysis,
      if (resolutionTimestamp != null) 'resolutionTimestamp': resolutionTimestamp,
      if (lastStatusUpdateBy != null) 'lastStatusUpdateBy': lastStatusUpdateBy,
      if (lastStatusUpdateAt != null) 'lastStatusUpdateAt': lastStatusUpdateAt,
      'isUnresolved': isUnresolved,
    };
  }
}