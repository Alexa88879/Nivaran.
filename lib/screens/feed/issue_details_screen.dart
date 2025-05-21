// lib/screens/feed/issue_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/issue_model.dart';
import '../../widgets/issue_card.dart'; // We'll reuse IssueCard to display details
import 'dart:developer' as developer;

class IssueDetailsScreen extends StatefulWidget {
  final String issueId;

  const IssueDetailsScreen({super.key, required this.issueId});

  @override
  State<IssueDetailsScreen> createState() => _IssueDetailsScreenState();
}

class _IssueDetailsScreenState extends State<IssueDetailsScreen> {
  Future<Issue?>? _issueFuture;

  @override
  void initState() {
    super.initState();
    _issueFuture = _fetchIssueDetails();
  }

  Future<Issue?> _fetchIssueDetails() async {
    if (widget.issueId.isEmpty || widget.issueId == 'error_no_id') {
      developer.log("IssueDetailsScreen: Invalid or missing issueId provided.", name: "IssueDetailsScreen");
      return null;
    }
    try {
      developer.log("IssueDetailsScreen: Fetching details for issueId: ${widget.issueId}", name: "IssueDetailsScreen");
      DocumentSnapshot<Map<String, dynamic>> issueDoc = await FirebaseFirestore
          .instance
          .collection('issues')
          .doc(widget.issueId)
          .get();

      if (issueDoc.exists) {
        return Issue.fromFirestore(issueDoc.data()!, issueDoc.id);
      } else {
        developer.log("IssueDetailsScreen: Issue with ID ${widget.issueId} not found.", name: "IssueDetailsScreen");
        return null;
      }
    } catch (e) {
      developer.log("Error fetching issue details for ${widget.issueId}: $e", name: "IssueDetailsScreen");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Issue Details"),
      ),
      body: FutureBuilder<Issue?>(
        future: _issueFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            developer.log("Error in FutureBuilder: ${snapshot.error}", name: "IssueDetailsScreen");
            return Center(child: Text("Error loading issue: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Issue not found or could not be loaded. It might have been deleted or there was an error.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final issue = snapshot.data!;
          // We can reuse the IssueCard here, or build a more detailed custom layout.
          // For now, reusing IssueCard is quick.
          return SingleChildScrollView(
            padding: const EdgeInsets.all(8.0),
            child: IssueCard(issue: issue),
          );
        },
      ),
    );
  }
}
