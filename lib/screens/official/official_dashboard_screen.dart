// lib/screens/official/official_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_profile_service.dart';
import '../../utils/update_checker.dart';
import '../../models/issue_model.dart';
import '../../services/auth_service.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'official_statistics_screen.dart';

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
    // _setupStream() will be called by didChangeDependencies first time
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Moved stream setup and initial update check here
    // to ensure UserProfileService is available via Provider.
    if (!_hasCheckedUpdate) {
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
      if (mounted && !_hasCheckedUpdate) {
        UpdateChecker.checkForUpdate(context);
        _hasCheckedUpdate = true; // Set it so it doesn't re-check immediately
      }
    } else if (state == AppLifecycleState.paused) {
       _hasCheckedUpdate = false; // Reset when paused
    }
  }


  void _setupStream() {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false); // listen: false is fine here
    final officialDepartment = userProfileService.currentUserProfile?.department;
    final currentUsername = userProfileService.currentUserProfile?.username;

    // Only update if the department has actually changed or stream is not yet set
    if (userProfileService.currentUserProfile != null && userProfileService.currentUserProfile!.isOfficial) {
      if (officialDepartment != null && (officialDepartment != _departmentName || _departmentIssuesStream == null)) {
        developer.log("OfficialDashboard: Setting up stream for department: $officialDepartment", name: "OfficialDashboard");
        if(mounted){ // Check mounted before calling setState
          setState(() {
            _departmentName = officialDepartment;
            _username = currentUsername ?? "Official";
            _departmentIssuesStream = FirebaseFirestore.instance
              .collection('issues')
              .where('assignedDepartment', isEqualTo: _departmentName)
              // Add more default sorting if needed, e.g., by timestamp or urgency
              .orderBy('timestamp', descending: true) 
              .snapshots();
          });
        }
      } else if (officialDepartment == null && _departmentName != "Not Assigned") {
         developer.log("OfficialDashboard: User is official but department is null.", name: "OfficialDashboard");
         if(mounted){
           setState(() {
             _departmentName = "Not Assigned";
             _username = currentUsername ?? "Official";
             _departmentIssuesStream = null; // No issues to show if not assigned
           });
         }
      }
    } else if (userProfileService.currentUserProfile == null && !userProfileService.isLoadingProfile && mounted) {
       developer.log("OfficialDashboard: CurrentUserProfile is null and not loading. Potential logout.", name: "OfficialDashboard");
       // Handled by AuthWrapper usually
    }
  }


  Future<void> _updateIssueStatus(String issueId, String newStatus) async {
    try {
      Map<String, dynamic> updateData = {'status': newStatus};
      if (newStatus == 'Resolved') {
        updateData['resolutionTimestamp'] = FieldValue.serverTimestamp();
      }
      updateData['lastStatusUpdateBy'] = _username;
      updateData['lastStatusUpdateAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('issues').doc(issueId).update(updateData);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Issue $issueId status updated to $newStatus.')));
    } catch (e) {
      developer.log("Failed to update status for $issueId: $e", name: "OfficialDashboard");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    return DateFormat('dd MMM yy, hh:mm a').format(timestamp.toDate());
  }

  // --- Helper for Urgency Color (same as in IssueCard) ---
  Color _getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'high':
        return Colors.red.shade700; // Slightly darker for official view
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: // Home
        return _buildIssuesList();
      case 1: // Stats
        return const OfficialStatisticsScreen();
      case 2: // Notifications
        return Center(
            child: Text("Alerts Screen (TODO)\n(Coming Soon!)",
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
              // AuthWrapper will handle navigation to RoleSelectionScreen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList() {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false); 

    if (_departmentName == "Loading..." || (userProfileService.isLoadingProfile && _departmentIssuesStream == null)) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Loading dashboard...", style: TextStyle(fontSize: 16))]));
    }
    if (_departmentName == "Not Assigned") {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Your account is official but not yet assigned to a department. Please contact an administrator.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.orangeAccent))));
    }
    if (_departmentIssuesStream == null) {
        return Center(child: Text('Initializing issue feed for $_departmentName...', style: const TextStyle(fontSize: 16)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _departmentIssuesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          developer.log("Error in department issues stream: ${snapshot.error}", name: "OfficialDashboard");
          return Center(child: Text('Error loading issues: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No active issues currently assigned to $_departmentName.', style: TextStyle(fontSize: 16, color: Colors.grey[700])));
        }

        final issuesDocs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: issuesDocs.length,
          itemBuilder: (context, index) {
            final issueData = issuesDocs[index].data() as Map<String, dynamic>;
            final issueId = issuesDocs[index].id;
            final issue = Issue.fromFirestore(issueData, issueId);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding( 
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Reported by: ${issue.username}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text("On: ${_formatTimestamp(issue.timestamp)}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                          tooltip: "Update Status",
                          onSelected: (String newStatus) => _updateIssueStatus(issue.id, newStatus),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            _buildPopupMenuItem('Acknowledged', issue.status),
                            _buildPopupMenuItem('In Progress', issue.status),
                            _buildPopupMenuItem('Addressed', issue.status),
                            _buildPopupMenuItem('Resolved', issue.status),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(issue.description, style: const TextStyle(fontSize: 14.5, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        Chip(
                          avatar: Icon(Icons.category_outlined, size: 15, color: Theme.of(context).colorScheme.primary),
                          label: Text(issue.category, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha((0.4 * 255).round()), // FIX: withOpacity to withAlpha
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (issue.urgency != null && issue.urgency!.isNotEmpty)
                          Chip(
                            avatar: Icon(Icons.priority_high_rounded, size: 15, color: _getUrgencyColor(issue.urgency)),
                            label: Text(issue.urgency!, style: TextStyle(fontSize: 11.5, color: _getUrgencyColor(issue.urgency), fontWeight: FontWeight.w500)),
                            backgroundColor: _getUrgencyColor(issue.urgency).withAlpha((0.15 * 255).round()), // FIX: withOpacity to withAlpha
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (issue.tags != null && issue.tags!.isNotEmpty)
                          ...issue.tags!.map((tag) => Chip( // FIX: Removed .toList()
                                label: Text("#$tag", style: TextStyle(fontSize: 10.5, color: Colors.blueGrey[700])),
                                backgroundColor: Colors.blueGrey[50],
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(child: Text(issue.location.address, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    if (issue.imageUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            issue.imageUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(height: 180, color: Colors.grey[200], child: Center(child: Icon(Icons.broken_image, color: Colors.grey[400]))),
                            loadingBuilder: (context, child, progress) => progress == null ? child : Container(height: 180, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                          ),
                        ),
                      ),
                    Divider(height: 20, thickness: 0.5, color: Colors.grey[300]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(Icons.thumb_up_alt_outlined, "${issue.upvotes} Upvotes", Colors.green),
                        _buildInfoChip(Icons.thumb_down_alt_outlined, "${issue.downvotes} Downvotes", Colors.red),
                        _buildInfoChip(Icons.comment_outlined, "${issue.commentsCount} Comments", Colors.blueAccent),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, String currentStatus) {
    return PopupMenuItem<String>(value: value, enabled: value != currentStatus, child: Text(value, style: TextStyle(color: value == currentStatus ? Colors.grey : null)));
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color.withAlpha((0.8 * 255).round())), // FIX: withOpacity to withAlpha
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // _getStatusColor method was removed as it was unused.

  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (userProfileService.isLoadingProfile && userProfileService.currentUserProfile == null) {
      return Scaffold(appBar: AppBar(title: const Text("Loading Dashboard...")), body: const Center(child: CircularProgressIndicator()));
    }

    if (!(userProfileService.currentUserProfile?.isOfficial ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
      });
      return Scaffold(appBar: AppBar(title: const Text('Access Denied')), body: const Center(child: Text('Redirecting...', style: TextStyle(fontSize: 16))));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${_departmentName == "Not Assigned" || _departmentName == "Loading..." ? "Official Dashboard" : _departmentName} Issues', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [IconButton(icon: const Icon(Icons.logout_outlined), tooltip: 'Logout', onPressed: () async => await authService.signOut(context))],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active_outlined), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}
