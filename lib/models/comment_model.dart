import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String text;
  final String userId;
  final String username;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.text,
    required this.userId,
    required this.username,
    required this.timestamp,
  });

  factory Comment.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Comment(
      id: documentId,
      text: data['text'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? 'Anonymous',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'userId': userId,
      'username': username,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}