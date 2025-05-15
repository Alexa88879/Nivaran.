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

   Map<String, dynamic> toMap() { // Added toMap for consistency
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
}

class Issue {
  final String id;
  final String description;
  final String category; // <<--- ADDED CATEGORY
  final String? urgency; // Optional for now
  final String imageUrl;
  final Timestamp timestamp;
  final LocationModel location;
  final String userId;
  final String username;
  final String status;
  final String? assignedDepartment; // For routing
  final int upvotes;
  final int downvotes;
  final Map<String, VoteType> voters; 
  final int commentsCount;
  final int affectedUsersCount; // For community complaints
  final List<String> affectedUserIds; // For community complaints

  Issue({
    required this.id,
    required this.description,
    required this.category, // <<--- ADDED CATEGORY
    this.urgency,
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
    List<String>? affectedUserIds, // Make it take a list, default to empty if null
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
      category: data['category'] as String? ?? 'Uncategorized', // <<--- ADDED CATEGORY
      urgency: data['urgency'] as String?,
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
    );
  }

  Map<String, dynamic> toMap() { // Added toMap method
    return {
      'description': description,
      'category': category,
      if (urgency != null) 'urgency': urgency,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
      'location': location.toMap(),
      'userId': userId,
      'username': username,
      'status': status,
      if (assignedDepartment != null) 'assignedDepartment': assignedDepartment,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'voters': voters.map((key, value) => MapEntry(key, value.name)), // Store enum as string
      'commentsCount': commentsCount,
      'affectedUsersCount': affectedUsersCount,
      'affectedUserIds': affectedUserIds,
    };
  }
}