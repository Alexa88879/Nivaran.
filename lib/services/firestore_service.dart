// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/issue_model.dart'; 
import '../models/comment_model.dart';
import '../models/category_model.dart'; 
import 'dart:developer' as developer;


class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // --- Issue Methods (existing) ---
  Future<void> addIssue(Map<String, dynamic> issueData) async {
     if (_currentUser == null) {
      throw Exception("User not logged in.");
    }
    await _db.collection('issues').add(issueData);
  }

  Stream<List<Issue>> getIssuesStream() {
     return _db
        .collection('issues')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Issue.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> voteIssue(String issueId, String userId, VoteType newVote) async {
     if (_currentUser == null || _currentUser.uid != userId) {
      throw Exception("Authentication error or user mismatch.");
    }

    final issueRef = _db.collection('issues').doc(issueId);

    await _db.runTransaction((transaction) async {
      final DocumentSnapshot issueSnapshot = await transaction.get(issueRef);
      if (!issueSnapshot.exists) {
        throw Exception("Issue does not exist.");
      }

      final issueData = issueSnapshot.data() as Map<String, dynamic>;
      int currentUpvotes = issueData['upvotes'] ?? 0;
      int currentDownvotes = issueData['downvotes'] ?? 0;
      Map<String, dynamic> currentVoters = Map<String, dynamic>.from(issueData['voters'] ?? {});

      VoteType? previousVote = currentVoters.containsKey(userId)
          ? (currentVoters[userId] == 'upvote' ? VoteType.upvote : VoteType.downvote)
          : null;

      if (previousVote == newVote) { 
        if (newVote == VoteType.upvote) {
          currentUpvotes--;
        }
        if (newVote == VoteType.downvote) {
          currentDownvotes--;
        }
        currentVoters.remove(userId);
      } else { 
        if (previousVote == VoteType.upvote) {
          currentUpvotes--;
        }
        if (previousVote == VoteType.downvote) {
          currentDownvotes--;
        }
        
        if (newVote == VoteType.upvote) {
          currentUpvotes++;
        }
        if (newVote == VoteType.downvote) {
          currentDownvotes++;
        }
        currentVoters[userId] = newVote.name; 
      }
      
      transaction.update(issueRef, {
        'upvotes': currentUpvotes.clamp(0, 1000000), 
        'downvotes': currentDownvotes.clamp(0, 1000000),
        'voters': currentVoters,
      });
    });
  }

  // --- Comment Methods (existing) ---
  Future<void> addComment(String issueId, String text) async {
     if (_currentUser == null) {
      throw Exception("User not logged in.");
    }
    final userDoc = await _db.collection('users').doc(_currentUser.uid).get();
    String username;
    if (userDoc.exists && userDoc.data()?['username'] != null) {
      username = userDoc.data()!['username'];
    } else {
      username = _currentUser.displayName ?? 'Anonymous';
    }
    final comment = Comment(
      id: '', 
      text: text,
      userId: _currentUser.uid,
      username: username,
      timestamp: DateTime.now(),
    );
    await _db.collection('issues').doc(issueId).collection('comments').add(comment.toMap());
    await _db.collection('issues').doc(issueId).update({
      'commentsCount': FieldValue.increment(1),
    });
  }

  Stream<List<Comment>> getCommentsStream(String issueId) {
    return _db
        .collection('issues')
        .doc(issueId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<List<Map<String, dynamic>>> getAdminCommentsForIssue(String issueId) async {
     if (_currentUser == null) {
      throw Exception("User not logged in.");
    }
    final userDoc = await _db.collection('users').doc(_currentUser.uid).get();
    final userRole = userDoc.data()?['role'] as String?;

    if (userRole != 'admin') {
      throw Exception("Unauthorized access");
    }
    final commentsSnapshot = await _db
        .collection('issues')
        .doc(issueId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .get();
    return commentsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
        'timestamp': (data['timestamp'] as Timestamp).toDate().toString(),
      };
    }).toList();
  }

  Future<List<CategoryModel>> fetchIssueCategories() async {
    try {
      final snapshot = await _db
          .collection('issueCategories')
          .where('isActive', isEqualTo: true) 
          .orderBy('sortOrder') 
          .get();
      
      if (snapshot.docs.isEmpty) {
        developer.log('No active issue categories found in Firestore.', name: 'FirestoreService');
        return []; 
      }
      
      return snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();
    } catch (e, s) {
      developer.log('Error fetching issue categories: $e', name: 'FirestoreService', error: e, stackTrace: s);
      return []; 
    }
  }

  // --- NEW METHOD TO FETCH DISTINCT DEPARTMENT NAMES ---
  Future<List<String>> fetchDistinctDepartmentNames() async {
    try {
      final snapshot = await _db
          .collection('issueCategories') // We get departments from the categories
          .where('isActive', isEqualTo: true) // Consider only active categories
          .get();

      if (snapshot.docs.isEmpty) {
        developer.log('No active issue categories found to derive departments.', name: 'FirestoreService');
        return [];
      }

      // Use a Set to store unique department names, then convert to List
      final Set<String> departmentSet = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final departmentName = data['defaultDepartment'] as String?;
        if (departmentName != null && departmentName.isNotEmpty) {
          departmentSet.add(departmentName);
        }
      }
      
      final List<String> distinctDepartments = departmentSet.toList();
      distinctDepartments.sort(); // Sort alphabetically for consistent dropdown order
      
      // Optionally add a generic "Other" department if not already present from categories
      // if (!distinctDepartments.contains("Other Department")) {
      //   distinctDepartments.add("Other Department");
      // }

      developer.log('Fetched distinct departments: $distinctDepartments', name: 'FirestoreService');
      return distinctDepartments;

    } catch (e, s) {
      developer.log('Error fetching distinct department names: $e', name: 'FirestoreService', error: e, stackTrace: s);
      return [];
    }
  }
}
