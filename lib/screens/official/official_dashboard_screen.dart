// lib/screens/official/official_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_profile_service.dart';
import '../../utils/update_checker.dart';
import '../../models/issue_model.dart'; // Using your provided Issue model
// import '../../widgets/issue_card.dart'; // If you have this, consider using it
import '../../services/auth_service.dart'; // For logout
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'official_statistics_screen.dart'; // Ensure this path is correct

class OfficialDashboardScreen extends StatefulWidget {
  const OfficialDashboardScreen({super.key});

  @override
  State<OfficialDashboardScreen> createState() => _OfficialDashboardScreenState();
}

class _OfficialDashboardScreenState extends State<OfficialDashboardScreen> with WidgetsBindingObserver {
  Stream<QuerySnapshot>? _departmentIssuesStream;
  String? _departmentName = "Loading...";
  String? _username = "Official";
  int _selectedIndex = 0;
  bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedUpdate) {
      // Only check for updates once when the screen is first loaded
      UpdateChecker.checkForUpdate(context);
      _hasCheckedUpdate = true;
    }
    _setupStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only check for updates when app is resumed and the screen is mounted
      if (mounted && !_hasCheckedUpdate) {
        UpdateChecker.checkForUpdate(context);
        _hasCheckedUpdate = true;
      }
    } else if (state == AppLifecycleState.paused) {
      // Reset the flag when app is paused, so it will check again when resumed
      _hasCheckedUpdate = false;
    }
  }


  void _setupStream() {
    final userProfileService =
        Provider.of<UserProfileService>(context, listen: false);
    final officialDepartment = userProfileService.currentUserProfile?.department;
    final currentUsername = userProfileService.currentUserProfile?.username;

    if (userProfileService.currentUserProfile != null && userProfileService.currentUserProfile!.isOfficial) {
      if (officialDepartment != null && (officialDepartment != _departmentName || _departmentIssuesStream == null)) {
        developer.log(
            "OfficialDashboard: Setting up stream for department: $officialDepartment",
            name: "OfficialDashboard");
        setState(() {
          _departmentName = officialDepartment;
          _username = currentUsername ?? "Official";
          _departmentIssuesStream = FirebaseFirestore.instance
            .collection('issues')
            .where('assignedDepartment', isEqualTo: _departmentName)
            .snapshots();
        });
      } else if (officialDepartment == null) {
        developer.log(
            "OfficialDashboard: User is official but department is null. Waiting for admin assignment.",
            name: "OfficialDashboard");
        setState(() {
          _departmentName = "Not Assigned";
          _username = currentUsername ?? "Official";
          _departmentIssuesStream = null;
        });
      }
    } else if (userProfileService.currentUserProfile == null && !userProfileService.isLoadingProfile) {
      developer.log("OfficialDashboard: CurrentUserPofile is null and not loading.", name: "OfficialDashboard");
    }
  }

  Future<void> _updateIssueStatus(String issueId, String newStatus) async {
    try {
      Map<String, dynamic> updateData = {'status': newStatus};
      if (newStatus == 'Resolved') {
        updateData['resolutionTimestamp'] = FieldValue.serverTimestamp();
      }
      // Add audit fields
      updateData['lastStatusUpdateBy'] = _username; // or user ID
      updateData['lastStatusUpdateAt'] = FieldValue.serverTimestamp();


      await FirebaseFirestore.instance
          .collection('issues')
          .doc(issueId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Issue $issueId status updated to $newStatus.')),
        );
      }
    } catch (e) {
      developer.log("Failed to update status for $issueId: $e", name: "OfficialDashboard");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    final dateTime = timestamp.toDate();
    return DateFormat('dd MMM, yyyy hh:mm a').format(dateTime); // Added year for clarity
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Home
        return _buildIssuesList();
      case 1: // Stats
        return const OfficialStatisticsScreen();
      case 2: // Notifications
        return Center(
            child: Text("Notifications Screen (TODO)\n(Coming Soon!)",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey[600])));
      case 3: // Profile
        return _buildProfileScreen();
      default:
        return _buildIssuesList();
    }
  }

  Widget _buildProfileScreen() {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final profile = userProfileService.currentUserProfile;

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(Icons.account_circle, size: 64, color: Theme.of(context).colorScheme.onSecondaryContainer),
          ),
          const SizedBox(height: 16),
          Text(
            profile.username ?? "Official",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            profile.email ?? "",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "Department: ${profile.department ?? "Not Assigned"}",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            "Role: Official",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList() {
    final userProfileService = Provider.of<UserProfileService>(context);

    if (_departmentName == "Loading..." || (userProfileService.isLoadingProfile && _departmentIssuesStream == null)) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Loading dashboard...", style: TextStyle(fontSize: 16)),
        ],
      ));
    }

    if (_departmentName == "Not Assigned") {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Your account is official but not yet assigned to a department. Please contact an administrator to gain full access.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.orangeAccent),
          ),
        ),
      );
    }
    if (_departmentIssuesStream == null) { // Could happen if _setupStream condition for department name is met but stream init fails
        return Center(child: Text('Initializing issue feed for $_departmentName...', style: const TextStyle(fontSize: 16)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _departmentIssuesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) { // Show loader if waiting and no data yet
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          developer.log("Error in department issues stream: ${snapshot.error}",
              name: "OfficialDashboard");
          return Center(child: Text('Error loading issues: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text(
                  'No active issues currently assigned to $_departmentName.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ));
        }

        final issuesDocs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: issuesDocs.length,
          itemBuilder: (context, index) {
            final issueData =
                issuesDocs[index].data() as Map<String, dynamic>;
            final issueId = issuesDocs[index].id;
            final issue = Issue.fromFirestore(issueData, issueId); // Using your Issue model

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          child: Icon(Icons.person_pin_circle_outlined, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(issue.username,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(_formatTimestamp(issue.timestamp),
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 12)),
                              const SizedBox(height: 4),
                              Wrap( // Use Wrap for better spacing of chips
                                spacing: 6.0,
                                runSpacing: 4.0,
                                children: [
                                  Chip(
                                    label: Text(issue.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                    backgroundColor: _getStatusColor(issue.status).withAlpha((0.15 * 255).round()), // Replaced withOpacity
                                    side: BorderSide(color: _getStatusColor(issue.status).withAlpha((0.5 * 255).round()), width: 0.5), // Replaced withOpacity
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    labelPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                   Chip(
                                    avatar: Icon(Icons.category_outlined, size: 12, color: Theme.of(context).colorScheme.secondary),
                                    label: Text(issue.category, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary)),
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha((0.3 * 255).round()), // Replaced withOpacity
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    labelPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (issue.urgency != null && issue.urgency!.isNotEmpty)
                                    Chip(
                                      avatar: const Icon(Icons.priority_high_rounded, size: 12, color: Colors.redAccent),
                                      label: Text(issue.urgency!, style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
                                      backgroundColor: Colors.red.withAlpha((0.1 * 255).round()), // Replaced withOpacity
                                      side: BorderSide.none,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      labelPadding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: "Update Status",
                          onSelected: (String newStatus) {
                            _updateIssueStatus(issue.id, newStatus);
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            _buildPopupMenuItem('Acknowledged', issue.status),
                            _buildPopupMenuItem('In Progress', issue.status),
                            _buildPopupMenuItem('Addressed', issue.status),
                            _buildPopupMenuItem('Resolved', issue.status),
                            // Add other relevant statuses for officials
                            // _buildPopupMenuItem('Needs Information', issue.status),
                            // _buildPopupMenuItem('Rejected', issue.status),
                          ],
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.description,
                              style: const TextStyle(fontSize: 14.5, height: 1.4)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  issue.location.address,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    ),
                  ),
                  if (issue.imageUrl.isNotEmpty) // Check directly for empty string as per your model
                    Container(
                      width: double.infinity,
                      height: 220,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(issue.imageUrl),
                          fit: BoxFit.cover,
                           // Optional: Add error builder for NetworkImage
                          onError: (exception, stackTrace) {
                            developer.log("Error loading image: $exception", name: "OfficialDashboard");
                            // You could return a placeholder widget here too
                          },
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12), // Adjusted padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                            Icons.thumb_up_alt_outlined,
                            "Upvotes",
                            issue.upvotes, // Using direct field from your model
                            () {
                              developer.log("Upvote pressed for ${issue.id}. Current upvotes: ${issue.upvotes}");
                              // TODO: Implement upvote logic (e.g., call a service method)
                              // This usually involves checking current user's vote in issue.voters
                              // and then updating Firestore.
                            }),
                        _buildActionButton(
                            Icons.thumb_down_alt_outlined, // Downvote icon
                            "Downvotes",
                            issue.downvotes, // Using direct field from your model
                            () {
                              developer.log("Downvote pressed for ${issue.id}. Current downvotes: ${issue.downvotes}");
                              // TODO: Implement downvote logic
                            }),
                        _buildActionButton(
                            Icons.comment_outlined,
                            "Comments",
                             issue.commentsCount, // Using direct field from your model
                            () {
                              developer.log("Comment pressed for ${issue.id}. Current comments: ${issue.commentsCount}");
                              // TODO: Navigate to comments screen or show comment dialog
                              // Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(issueId: issue.id)));
                            }),
                        _buildActionButton(
                            Icons.people_alt_outlined, // Icon for affected users
                            "Affected",
                             issue.affectedUsersCount, // Using direct field
                            () {
                              developer.log("Affected users count: ${issue.affectedUsersCount} for ${issue.id}.");
                              // TODO: Maybe show list of affected users if clicked, or just info
                            }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper to build PopupMenuItems and disable if it's the current status
  PopupMenuItem<String> _buildPopupMenuItem(String value, String currentStatus) {
    return PopupMenuItem<String>(
      value: value,
      enabled: value != currentStatus, // Disable if it's the current status
      child: Text(value, style: TextStyle(color: value == currentStatus ? Colors.grey : null)),
    );
  }

   Color _getStatusColor(String? status) {
    switch (status) {
      case 'Reported':
      case 'Pending':
        return Colors.orange.shade700;
      case 'Acknowledged':
        return Colors.blue.shade700;
      case 'In Progress':
        return Colors.lightBlue.shade700;
      case 'Addressed':
      case 'Resolved':
        return Colors.green.shade700;
      case 'Rejected':
      case 'Closed':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (userProfileService.isLoadingProfile && userProfileService.currentUserProfile == null) {
      return Scaffold(
          appBar: AppBar(title: const Text("Loading Dashboard...")),
          body: const Center(child: CircularProgressIndicator()));
    }

    if (!(userProfileService.currentUserProfile?.isOfficial ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/role_selection', (route) => false);
        }
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('Redirecting...', style: TextStyle(fontSize: 16))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${_departmentName == "Not Assigned" || _departmentName == "Loading..." ? "Official Dashboard" : _departmentName} Issues',
             style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () async {
              await authService.signOut(context);
            },
          )
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active_outlined), label: 'Alerts'), // Changed "Notifications" to "Alerts"
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, int count, VoidCallback onPressed) {
  return Expanded( // Use Expanded to give equal space if desired
    child: TextButton.icon(
      icon: Icon(icon, size: 18, color: Colors.grey[700]), // Slightly smaller icon
      label: Text("$label ($count)", style: TextStyle(color: Colors.grey[800], fontSize: 11, fontWeight: FontWeight.w500)),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), // Adjust padding
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
    ),
  );
}
}