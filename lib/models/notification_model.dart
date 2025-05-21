// lib/models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id; // Document ID from Firestore
  final String userId; // UID of the recipient
  final String title;
  final String body;
  final String? issueId; // Optional: if related to a specific issue
  final String type; // e.g., 'status_update', 'new_comment', 'admin_message'
  bool isRead;
  final Timestamp createdAt;
  final String? navigateTo; // Optional: route to navigate to on tap
  final String? senderId;
  final String? senderName;
  final String? iconUrl; // Optional: URL for a specific icon for the notification

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.issueId,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.navigateTo,
    this.senderId,
    this.senderName,
    this.iconUrl,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      issueId: data['issueId'] as String?,
      type: data['type'] as String? ?? 'general',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      navigateTo: data['navigateTo'] as String?,
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      iconUrl: data['iconUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      if (issueId != null) 'issueId': issueId,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt,
      if (navigateTo != null) 'navigateTo': navigateTo,
      if (senderId != null) 'senderId': senderId,
      if (senderName != null) 'senderName': senderName,
      if (iconUrl != null) 'iconUrl': iconUrl,
    };
  }
}
