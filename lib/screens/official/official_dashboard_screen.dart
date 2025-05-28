// lib/screens/official/official_dashboard_screen.dart
import 'dart:async'; // Added for StreamSubscription
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_profile_service.dart';
import '../../utils/update_checker.dart';
import '../../models/issue_model.dart';
import '../../models/category_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'official_statistics_screen.dart';
import '../../widgets/comments_dialog.dart';
import '../notifications/notifications_screen.dart';

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

  String? _selectedFilterCategory;
  String? _selectedFilterUrgency;
  String? _selectedFilterStatus;

  String _currentSortBy = 'timestamp';
  bool _isSortDescending = true;

  List<CategoryModel> _fetchedFilterCategories = [];
  final List<String> _allUrgencyLevels = ['Low', 'Medium', 'High'];
  final List<String> _allStatuses = ['Reported', 'Acknowledged', 'In Progress', /*'Addressed',*/ 'Resolved', 'Rejected']; // Removed 'Addressed' as per schema

  final FirestoreService _firestoreService = FirestoreService();
  bool _hasUnreadNotifications = false;
  StreamSubscription? _notificationSubscription;

  // State for managing "Show More" for original text in official dashboard list
  final Map<String, bool> _expandedIssueOriginalText = {};
  static const int shortDescriptionLengthThreshold = 70;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchFilterCategories();
  }

  Future<void> _fetchFilterCategories() async {
    if (!mounted) return;
    try {
      final categories = await _firestoreService.fetchIssueCategories();
      if (mounted) {
        setState(() {
          _fetchedFilterCategories = categories;
        });
      }
    } catch (e) {
      developer.log("Error fetching categories for filter: $e", name: "OfficialDashboard");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not load filter categories."))
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (!_hasCheckedUpdate) {
          UpdateChecker.checkForUpdate(context);
          _hasCheckedUpdate = true;
        }
        _setupStream();
        _setupNotificationListener();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted && !_hasCheckedUpdate) {
        UpdateChecker.checkForUpdate(context);
        _hasCheckedUpdate = true;
      }
      if (mounted) {
        _setupNotificationListener();
      }
    } else if (state == AppLifecycleState.paused) {
       _hasCheckedUpdate = false;
    }
  }

  void _setupNotificationListener() {
    if (!mounted) return;
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final officialUid = userProfileService.currentUserProfile?.uid;

    if (officialUid != null && officialUid.isNotEmpty) {
      _notificationSubscription?.cancel();
      _notificationSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: officialUid)
          .where('isRead', isEqualTo: false)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _hasUnreadNotifications = snapshot.docs.isNotEmpty;
          });
        }
      }, onError: (error) {
        developer.log("Error in notification listener: $error", name: "OfficialDashboard");
        if (mounted) {
          setState(() {
            _hasUnreadNotifications = false;
          });
        }
      });
    } else {
      if (mounted && _hasUnreadNotifications) {
        setState(() {
          _hasUnreadNotifications = false;
        });
      }
      _notificationSubscription?.cancel();
    }
  }

  void _setupStream() {
    if (!mounted) return;
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final officialDepartment = userProfileService.currentUserProfile?.department;
    final currentUsername = userProfileService.currentUserProfile?.username;

    if (userProfileService.currentUserProfile != null && userProfileService.currentUserProfile!.isOfficial) {
      if (officialDepartment != null && officialDepartment.isNotEmpty) {
        if (officialDepartment != _departmentName || _username != currentUsername) {
           if (mounted) {
             setState(() {
               _departmentName = officialDepartment;
               _username = currentUsername ?? "Official";
             });
           }
        }

        Query query = FirebaseFirestore.instance
            .collection('issues')
            .where('assignedDepartment', isEqualTo: officialDepartment);

        if (_selectedFilterCategory != null) {
          query = query.where('category', isEqualTo: _selectedFilterCategory);
        }
        if (_selectedFilterUrgency != null) {
          query = query.where('urgency', isEqualTo: _selectedFilterUrgency);
        }
        if (_selectedFilterStatus != null) {
          query = query.where('status', isEqualTo: _selectedFilterStatus);
        }

        query = query.orderBy(_currentSortBy, descending: _isSortDescending);
        if (_currentSortBy != 'timestamp') {
          query = query.orderBy('timestamp', descending: true);
        }

        if(mounted){
          if (_departmentIssuesStream == null || officialDepartment != _departmentName || currentUsername != _username) {
            setState(() {
              _departmentIssuesStream = query.snapshots();
            });
          } else { // If filters or sort changed, also update the stream
             setState(() {
              _departmentIssuesStream = query.snapshots();
            });
          }
        }
        developer.log("OfficialDashboard: Stream setup. Dept: $officialDepartment, Filters: Cat: $_selectedFilterCategory, Urg: $_selectedFilterUrgency, Stat: $_selectedFilterStatus. Sort: $_currentSortBy Desc: $_isSortDescending", name: "OfficialDashboard");

      } else {
         developer.log("OfficialDashboard: User is official but department is null or empty.", name: "OfficialDashboard");
         if(mounted){
           setState(() {
             _departmentName = "Not Assigned";
             _username = currentUsername ?? "Official";
             _departmentIssuesStream = FirebaseFirestore.instance.collection('issues').where('assignedDepartment', isEqualTo: 'non_existent_value_to_get_empty_stream').snapshots();
           });
         }
      }
      _setupNotificationListener();
    } else if (userProfileService.currentUserProfile == null && !userProfileService.isLoadingProfile && mounted) {
       developer.log("OfficialDashboard: User not official or profile not loaded. Clearing stream.", name: "OfficialDashboard");
       if(mounted) {
         setState(() {
           _departmentName = "Access Denied";
           _departmentIssuesStream = FirebaseFirestore.instance.collection('issues').where('assignedDepartment', isEqualTo: 'non_existent_value_to_get_empty_stream').snapshots();
           _hasUnreadNotifications = false;
         });
       }
        _notificationSubscription?.cancel();
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
      // Update isUnresolved based on new status
      updateData['isUnresolved'] = !(newStatus == 'Resolved' || newStatus == 'Rejected');


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

  Color _getUrgencyColor(String? urgency) {
     switch (urgency?.toLowerCase()) {
      case 'high': return Colors.red.shade700;
      case 'medium': return Colors.orange.shade700;
      case 'low': return Colors.blue.shade700;
      default: return Colors.grey.shade600;
    }
  }

  void _showFilterDialog() {
    String? tempCategory = _selectedFilterCategory;
    String? tempUrgency = _selectedFilterUrgency;
    String? tempStatus = _selectedFilterStatus;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Issues'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Category'),
                      value: tempCategory,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Categories')),
                        ..._fetchedFilterCategories.map((CategoryModel category) => DropdownMenuItem<String>(value: category.name, child: Text(category.name)))
                      ],
                      onChanged: (String? newValue) => setDialogState(() => tempCategory = newValue),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Urgency'),
                      value: tempUrgency,
                      items: [const DropdownMenuItem<String>(value: null, child: Text('All Urgencies')), ..._allUrgencyLevels.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))],
                      onChanged: (String? newValue) => setDialogState(() => tempUrgency = newValue),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      value: tempStatus,
                      items: [const DropdownMenuItem<String>(value: null, child: Text('All Statuses')), ..._allStatuses.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value)))],
                      onChanged: (String? newValue) => setDialogState(() => tempStatus = newValue),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Clear Filters'),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _selectedFilterCategory = null;
                        _selectedFilterUrgency = null;
                        _selectedFilterStatus = null;
                         _expandedIssueOriginalText.clear(); // Clear expansion states on filter change
                      });
                      _setupStream();
                    }
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Apply'),
                  onPressed: () {
                     if (mounted) {
                        setState(() {
                          _selectedFilterCategory = tempCategory;
                          _selectedFilterUrgency = tempUrgency;
                          _selectedFilterStatus = tempStatus;
                          _expandedIssueOriginalText.clear(); // Clear expansion states on filter change
                        });
                        _setupStream();
                     }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSortOptions() {
     showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(leading: Icon(_currentSortBy == 'timestamp' ? (_isSortDescending ? Icons.arrow_downward : Icons.arrow_upward) : null), title: const Text('Sort by Date'), onTap: () => _applySort('timestamp')),
                ListTile(leading: Icon(_currentSortBy == 'urgency' ? (_isSortDescending ? Icons.arrow_downward : Icons.arrow_upward) : null), title: const Text('Sort by Urgency'), onTap: () => _applySort('urgency')),
                ListTile(leading: Icon(_currentSortBy == 'upvotes' ? (_isSortDescending ? Icons.arrow_downward : Icons.arrow_upward) : null), title: const Text('Sort by Upvotes'), onTap: () => _applySort('upvotes')),
              ],
            ),
          );
        });
  }

  void _applySort(String sortByField) {
    Navigator.pop(context);
    if (mounted) {
      setState(() {
        if (_currentSortBy == sortByField) {
          _isSortDescending = !_isSortDescending;
        } else {
          _currentSortBy = sortByField;
          _isSortDescending = true;
          if (sortByField == 'urgency') _isSortDescending = false;
        }
         _expandedIssueOriginalText.clear(); // Clear expansion states on sort change
      });
      _setupStream();
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildIssuesList();
      case 1: return const OfficialStatisticsScreen();
      case 2: return const NotificationsScreen();
      case 3: return _buildProfileScreen();
      default: return _buildIssuesList();
    }
  }

  Widget _buildProfileScreen() {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final profile = userProfileService.currentUserProfile;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    final String displayName = profile.username ?? profile.fullName ?? profile.email?.split('@')[0] ?? 'Official';
    final String? profileImageUrl = profile.profilePhotoUrl;

    return ListView(
        padding: const EdgeInsets.all(0),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: (profileImageUrl == null || profileImageUrl.isEmpty) && displayName.isNotEmpty
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  profile.email ?? "No email provided",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700], fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Chip(
                  avatar: Icon(Icons.work_outline_rounded, size: 18, color: Theme.of(context).primaryColorDark),
                  label: Text(
                    "Dept: ${profile.department ?? "Not Assigned"}",
                    style: TextStyle(fontSize: 13, color: Theme.of(context).primaryColorDark, fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: Theme.of(context).primaryColor.withAlpha(50),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
                 if (profile.designation != null && profile.designation!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Designation: ${profile.designation}",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildProfileOptionTile(context, icon: Icons.edit_outlined, title: 'Edit Profile', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit Profile - Coming Soon!")));
          }),
          _buildProfileOptionTile(context, icon: Icons.lock_outline_rounded, title: 'Change Password', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Change Password - Coming Soon!")));
          }),
          _buildProfileOptionTile(context, icon: Icons.history_edu_outlined, title: 'My Activity Log', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("My Activity - Coming Soon!")));
          }),
           _buildProfileOptionTile(context, icon: Icons.notifications_none_outlined, title: 'Notification Settings', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification Settings - Coming Soon!")));
          }),
          const Divider(height: 30, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text("Logout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: () async {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.signOut(context);
              },
            ),
          ),
        ],
      );
  }

  Widget _buildProfileOptionTile(BuildContext context, {required IconData icon, required String title, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
     if (_departmentName == "Access Denied") {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Access Denied. This dashboard is for officials.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.redAccent))));
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
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('No issues match current filters for $_departmentName.', style: TextStyle(fontSize: 16, color: Colors.grey[700]), textAlign: TextAlign.center,),
          ));
        }

        final issuesDocs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: issuesDocs.length,
          itemBuilder: (context, index) {
            final issueData = issuesDocs[index].data() as Map<String, dynamic>;
            final issueId = issuesDocs[index].id;
            final issue = Issue.fromFirestore(issueData, issueId);

            // Initialize expansion state for new issues
            _expandedIssueOriginalText.putIfAbsent(issue.id, () => issue.description.length <= shortDescriptionLengthThreshold);
            bool showOriginal = issue.originalSpokenText != null &&
                                issue.originalSpokenText!.isNotEmpty &&
                                issue.userInputLanguage != null &&
                                !issue.userInputLanguage!.toLowerCase().startsWith('en');
            bool isDescriptionLongForThisIssue = issue.description.length > shortDescriptionLengthThreshold;


            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              elevation: 2.5,
              shadowColor: Colors.grey.withAlpha(100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                              Text("Reported by: ${issue.username}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text("On: ${_formatTimestamp(issue.timestamp)}", style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey[800]),
                          tooltip: "Update Status",
                          onSelected: (String newStatus) => _updateIssueStatus(issue.id, newStatus),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            _buildPopupMenuItem('Acknowledged', issue.status),
                            _buildPopupMenuItem('In Progress', issue.status),
                            // _buildPopupMenuItem('Addressed', issue.status), // Removed as per schema
                            _buildPopupMenuItem('Resolved', issue.status),
                            _buildPopupMenuItem('Rejected', issue.status),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(issue.description, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87), maxLines: 3, overflow: TextOverflow.ellipsis),
                    // Display Original Spoken Text
                    if (showOriginal)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Original Report (in ${issue.userInputLanguage!.split('-')[0]}):",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (_expandedIssueOriginalText[issue.id]! || !isDescriptionLongForThisIssue)
                                  ? issue.originalSpokenText!
                                  : issue.originalSpokenText!.split('\n').first,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                fontSize: 13.0,
                                color: Colors.black.withAlpha(200),
                              ),
                              maxLines: (_expandedIssueOriginalText[issue.id]! || !isDescriptionLongForThisIssue) ? null : 1,
                              overflow: (_expandedIssueOriginalText[issue.id]! || !isDescriptionLongForThisIssue) ? TextOverflow.visible : TextOverflow.ellipsis,
                            ),
                            if (isDescriptionLongForThisIssue && (issue.originalSpokenText!.contains('\n') || issue.originalSpokenText!.length > 70))
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 20),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _expandedIssueOriginalText[issue.id] = !_expandedIssueOriginalText[issue.id]!;
                                  });
                                },
                                child: Text(
                                  _expandedIssueOriginalText[issue.id]! ? "Show less" : "Show more",
                                  style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12.0),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 6.0,
                      children: [
                        Chip(
                          avatar: Icon(Icons.category_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                          label: Text(issue.category, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (issue.urgency != null && issue.urgency!.isNotEmpty)
                          Chip(
                            avatar: Icon(Icons.priority_high_rounded, size: 16, color: _getUrgencyColor(issue.urgency)),
                            label: Text(issue.urgency!, style: TextStyle(fontSize: 12, color: _getUrgencyColor(issue.urgency), fontWeight: FontWeight.w500)),
                            backgroundColor: _getUrgencyColor(issue.urgency).withAlpha(40),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (issue.tags != null && issue.tags!.isNotEmpty)
                          ...issue.tags!.map((tag) => Chip(
                                label: Text("#$tag", style: TextStyle(fontSize: 11, color: Colors.blueGrey[800])),
                                backgroundColor: Colors.blueGrey[100],
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 15, color: Colors.grey[700]),
                        const SizedBox(width: 5),
                        Expanded(child: Text(issue.location.address, style: TextStyle(fontSize: 12.5, color: Colors.grey[800], fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    if (issue.imageUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            issue.imageUrl,
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(height: 190, color: Colors.grey[200], child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40))),
                            loadingBuilder: (context, child, progress) => progress == null ? child : Container(height: 190, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
                          ),
                        ),
                      ),
                    Divider(height: 24, thickness: 0.8, color: Colors.grey[350]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionChip(icon: Icons.thumb_up_alt_outlined, label: "${issue.upvotes} Upvotes", color: Colors.green.shade600, onTap: null),
                        _buildActionChip(icon: Icons.thumb_down_alt_outlined, label: "${issue.downvotes} Downvotes", color: Colors.red.shade600, onTap: null),
                        _buildActionChip(icon: Icons.chat_bubble_outline_rounded, label: "${issue.commentsCount} Comments", color: Colors.blueAccent.shade700, onTap: () {
                            showDialog(context: context, builder: (_) => CommentsDialog(issueId: issue.id, issueDescription: issue.description));
                        }),
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

  Widget _buildActionChip({ required IconData icon, required String label, required Color color, VoidCallback? onTap }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: onTap != null ? color.withAlpha(30) : Colors.transparent,
          border: Border.all(color: onTap != null ? color.withAlpha(150) : color.withAlpha(100), width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (userProfileService.isLoadingProfile && userProfileService.currentUserProfile == null) {
      return Scaffold(appBar: AppBar(title: const Text("Loading Dashboard...")), body: const Center(child: CircularProgressIndicator()));
    }

    if (!(userProfileService.currentUserProfile?.isOfficial ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
        }
      });
      return Scaffold(appBar: AppBar(title: const Text('Access Denied')), body: const Center(child: Text('Redirecting...', style: TextStyle(fontSize: 16))));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _departmentName == "Not Assigned" || _departmentName == "Loading..." || _departmentName == "Access Denied"
              ? "Official Dashboard"
              : '$_departmentName Issues',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)
        ),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list_alt), tooltip: 'Filter Issues', onPressed: _showFilterDialog),
          IconButton(icon: const Icon(Icons.sort_by_alpha_rounded), tooltip: 'Sort Issues', onPressed: _showSortOptions),
          IconButton(icon: const Icon(Icons.logout_outlined), tooltip: 'Logout', onPressed: () async {
             await authService.signOut(context);
          }),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (mounted) {
             setState(() => _selectedIndex = index);
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        items: [
          BottomNavigationBarItem(icon: Icon(_selectedIndex == 0 ? Icons.list_alt_rounded : Icons.list_alt_outlined), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(_selectedIndex == 1 ? Icons.bar_chart_rounded : Icons.bar_chart_outlined), label: 'Stats'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(_selectedIndex == 2 ? Icons.notifications_active : Icons.notifications_active_outlined),
                if (_hasUnreadNotifications)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(icon: Icon(_selectedIndex == 3 ? Icons.account_circle : Icons.account_circle_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}