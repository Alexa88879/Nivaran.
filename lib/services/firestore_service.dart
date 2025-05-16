// services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/issue_model.dart'; // Ensure this model is created
import '../models/comment_model.dart';
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Add a new issue
  Future<void> addIssue(Map<String, dynamic> issueData) async {
    if (_currentUser == null) {
      throw Exception("User not logged in.");
    }
    // Ensure all required fields are present, especially server timestamp for 'timestamp'
    await _db.collection('issues').add(issueData);
  }

  // Get a stream of all issues (example, you might have this in IssuesListScreen directly)
  Stream<List<Issue>> getIssuesStream() {
    return _db
        .collection('issues')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Issue.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Handle voting on an issue
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

      // Determine changes
      if (previousVote == newVote) { // User is clicking the same vote type again (un-voting)
        if (newVote == VoteType.upvote) currentUpvotes--;
        if (newVote == VoteType.downvote) currentDownvotes--;
        currentVoters.remove(userId);
      } else { // New vote or changing vote
        // Decrement count if changing vote
        if (previousVote == VoteType.upvote) currentUpvotes--;
        if (previousVote == VoteType.downvote) currentDownvotes--;
        
        // Increment count for new vote
        if (newVote == VoteType.upvote) currentUpvotes++;
        if (newVote == VoteType.downvote) currentDownvotes++;
        currentVoters[userId] = newVote.name; // Store as 'upvote' or 'downvote'
      }
      
      transaction.update(issueRef, {
        'upvotes': currentUpvotes.clamp(0, 1000000), // ensure non-negative
        'downvotes': currentDownvotes.clamp(0, 1000000),
        'voters': currentVoters,
      });
    });
  }

  // Add a new comment to an issue
  Future<void> addComment(String issueId, String text) async {
    if (_currentUser == null) {
      throw Exception("User not logged in.");
    }

    // Get user data to ensure we have the username
    final userDoc = await _db.collection('users').doc(_currentUser.uid).get();
    String username;
    
    if (userDoc.exists && userDoc.data()?['username'] != null) {
      username = userDoc.data()!['username'];
    } else {
      username = _currentUser.displayName ?? 'Anonymous';
    }

    final comment = Comment(
      id: '', // Will be set by Firestore
      text: text,
      userId: _currentUser.uid,
      username: username,
      timestamp: DateTime.now(),
    );

    // Add comment to Firestore
    await _db.collection('issues').doc(issueId).collection('comments').add(comment.toMap());

    // Update comment count on the issue
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

    // Get user role from Firestore
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
}
