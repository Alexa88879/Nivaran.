// lib/screens/feed/issue_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/issue_model.dart';
import '../../widgets/issue_card.dart';
import '../../widgets/issue_timeline_widget.dart';
import '../../widgets/issue_collaborations_widget.dart';
import '../../services/user_profile_service.dart';
import 'issue_collaboration_screen.dart';
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
          final userProfile = Provider.of<UserProfileService>(context).currentUserProfile;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Issue Card
                IssueCard(issue: issue),
                
                const SizedBox(height: 24),
                
                // Issue Timeline
                const Text(
                  'Issue Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('issues')
                      .doc(widget.issueId)
                      .collection('status_updates')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    List<Map<String, dynamic>> statusUpdates = [];
                    if (snapshot.hasData && snapshot.data != null) {
                      statusUpdates = snapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList();
                    }
                    
                    return IssueTimelineWidget(
                      issue: issue,
                      statusUpdates: statusUpdates,
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Collaborations Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Community Contributions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (userProfile != null)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IssueCollaborationScreen(
                                issueId: widget.issueId,
                                issue: issue,
                              ),
                            ),
                          );
                          
                          if (result == true) {
                            // Refresh the issue details if collaboration was added
                            setState(() {
                              _issueFuture = _fetchIssueDetails();
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Contribute'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                IssueCollaborationsWidget(issueId: widget.issueId),
              ],
            ),
          );
        },
      ),
    );
  }
}
