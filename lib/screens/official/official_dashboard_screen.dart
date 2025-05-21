// lib/screens/official/official_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // For asset loading
import 'dart:convert'; // For JSON decoding
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
import '../notifications/notifications_screen.dart'; // <-- IMPORT NotificationsScreen

class OfficialDashboardScreen extends StatefulWidget {
  const OfficialDashboardScreen({super.key});

  @override
  State<OfficialDashboardScreen> createState() => _OfficialDashboardScreenState();
}

class _OfficialDashboardScreenState extends State<OfficialDashboardScreen> with WidgetsBindingObserver {
  Stream<QuerySnapshot>? _departmentIssuesStream;
  String? _departmentName = "Loading...";
  String? _username = "Official";
  int _selectedIndex = 0; // Default to Issues List
  bool _hasCheckedUpdate = false;

  String? _selectedFilterCategory;
  String? _selectedFilterUrgency;
  String? _selectedFilterStatus;
  
  String _currentSortBy = 'timestamp'; 
  bool _isSortDescending = true;      

  List<CategoryModel> _fetchedFilterCategories = []; 
  final List<String> _allUrgencyLevels = ['Low', 'Medium', 'High'];
  final List<String> _allStatuses = ['Reported', 'Acknowledged', 'In Progress', 'Resolved', 'Rejected'];
  
  final FirestoreService _firestoreService = FirestoreService(); 
  // bool _isSeedingData = false; // Seeding button removed from this screen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchFilterCategories(); 
    // Initial setup for stream is now in didChangeDependencies or after profile load check
  }
  
  Future<void> _fetchFilterCategories() async {
    if (!mounted) return;
    try {
      final categories = await _firestoreService.fetchIssueCategories();
      if (mounted) {
        setState(() {
          _fetchedFilterCategories = categories;
        });
        if (categories.isEmpty) {
          developer.log("No active categories fetched for filter dialog.", name: "OfficialDashboard");
        }
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

  // Seeding function removed from here, as it's better placed elsewhere (e.g., admin tool or one-time script)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This ensures that when the screen is first built or dependencies change (like UserProfileService),
    // we attempt to set up the stream and check for updates.
    if (mounted) {
      _performInitialChecksAndSetupStream();
    }
  }
  
  Future<void> _performInitialChecksAndSetupStream() async {
    if (!mounted) return;

    if (!_hasCheckedUpdate) {
      await UpdateChecker.checkForUpdate(context);
      if (mounted) setState(() => _hasCheckedUpdate = true);
    }

    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final officialProfile = userProfileService.currentUserProfile;

    if (officialProfile != null && officialProfile.isOfficial) {
      final officialDepartment = officialProfile.department;
      final currentUsername = officialProfile.username;

      bool needsUIUpdate = false;
      if (officialDepartment != null && officialDepartment != _departmentName) {
        _departmentName = officialDepartment;
        needsUIUpdate = true;
      } else if (officialDepartment == null && _departmentName != "Not Assigned") {
        _departmentName = "Not Assigned";
        needsUIUpdate = true;
      }
      if (currentUsername != null && currentUsername != _username) {
        _username = currentUsername;
        needsUIUpdate = true;
      }
      
      if (needsUIUpdate && mounted) {
        setState(() {}); // Update UI with new department/username
      }
      _setupStreamQuery(); // Setup or re-setup the stream with current filters
    } else if (officialProfile == null && !userProfileService.isLoadingProfile) {
      // User might have logged out or profile failed to load
      if (mounted) {
        setState(() {
          _departmentName = "Error: Profile not loaded";
          _username = "Official";
          _departmentIssuesStream = null;
        });
      }
      developer.log("OfficialDashboard: CurrentUserProfile is null. Potential logout or load error.", name: "OfficialDashboard");
    }
    // If profile is loading, the build method will show a loader.
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _departmentIssuesStream = null; // Clear stream to avoid using after dispose
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
         _hasCheckedUpdate = false; // Reset to allow check on resume
         _performInitialChecksAndSetupStream();
      }
    } else if (state == AppLifecycleState.paused) {
       // _hasCheckedUpdate = false; // Or keep true if you only want one check per app session
    }
  }

  void _setupStreamQuery() {
    if (!mounted) return;
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final officialDepartment = userProfileService.currentUserProfile?.department;

    if (officialDepartment == null || !userProfileService.currentUserProfile!.isOfficial) {
      if (mounted) {
        setState(() => _departmentIssuesStream = null); // Clear stream if no valid department
      }
      return;
    }
        
    Query query = FirebaseFirestore.instance.collection('issues').where('assignedDepartment', isEqualTo: officialDepartment); 
    if (_selectedFilterCategory != null) query = query.where('category', isEqualTo: _selectedFilterCategory);
    if (_selectedFilterUrgency != null) query = query.where('urgency', isEqualTo: _selectedFilterUrgency);
    if (_selectedFilterStatus != null) query = query.where('status', isEqualTo: _selectedFilterStatus);
    
    query = query.orderBy(_currentSortBy, descending: _isSortDescending);
    if (_currentSortBy != 'timestamp') query = query.orderBy('timestamp', descending: true); 
    
    if(mounted) {
      setState(() => _departmentIssuesStream = query.snapshots());
    }
    developer.log("OfficialDashboard: Stream setup. Dept: $officialDepartment, Filters: Cat:$_selectedFilterCategory, Urg:$_selectedFilterUrgency, Stat:$_selectedFilterStatus. Sort: $_currentSortBy Desc:$_isSortDescending", name: "OfficialDashboard");
  }

  Future<void> _updateIssueStatus(String issueId, String newStatus) async {
    // ... (existing _updateIssueStatus logic remains the same)
    try {
      Map<String, dynamic> updateData = {'status': newStatus};
      if (newStatus == 'Resolved') updateData['resolutionTimestamp'] = FieldValue.serverTimestamp();
      
      // Get username from UserProfileService if possible, otherwise fallback
      final userProfileService = Provider.of<UserProfileService>(context, listen: false);
      final String updaterName = userProfileService.currentUserProfile?.username ?? _username ?? "Official";
      
      updateData['lastStatusUpdateBy'] = updaterName;
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

  Color _getUrgencyColor(String? urgency) {
     switch (urgency?.toLowerCase()) {
      case 'high': return Colors.red.shade700;
      case 'medium': return Colors.orange.shade700;
      case 'low': return Colors.blue.shade700;
      default: return Colors.grey.shade600;
    }
  }

  void _showFilterDialog() {
    // ... (existing _showFilterDialog logic remains the same)
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
                    if (_fetchedFilterCategories.isEmpty && _selectedFilterCategory == null) // Show only if no categories and no filter selected
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Loading categories for filter...", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                        ),
                    if (_fetchedFilterCategories.isNotEmpty || _selectedFilterCategory != null) // Show if categories exist or a filter is selected
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
                    if(mounted) {
                      setState(() {
                        _selectedFilterCategory = null;
                        _selectedFilterUrgency = null;
                        _selectedFilterStatus = null;
                        _setupStreamQuery(); 
                      });
                    }
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Apply'),
                  onPressed: () {
                    if(mounted) {
                      setState(() {
                        _selectedFilterCategory = tempCategory;
                        _selectedFilterUrgency = tempUrgency;
                        _selectedFilterStatus = tempStatus;
                        _setupStreamQuery(); 
                      });
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
    // ... (existing _showSortOptions logic remains the same)
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
    // ... (existing _applySort logic remains the same)
    Navigator.pop(context); 
    if(mounted) {
      setState(() {
        if (_currentSortBy == sortByField) {
          _isSortDescending = !_isSortDescending; 
        } else {
          _currentSortBy = sortByField;
          _isSortDescending = true; 
          // For urgency, typically higher urgency (e.g., 'High') should come first.
          // This requires custom sorting if 'urgency' is a string.
          // For simplicity, Firestore's string sort might not be ideal for urgency.
          // If urgency was numeric (High=3, Medium=2, Low=1), descending=true would work.
          // For string based, you might need to fetch and sort client-side or adjust how urgency is stored/queried.
          // For now, we'll keep it simple; 'High' might appear after 'Low' with default string sort.
        }
        _setupStreamQuery(); 
      });
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildIssuesList();
      case 1: return const OfficialStatisticsScreen();
      // --- MODIFIED: Return NotificationsScreen for index 2 ---
      case 2: return const NotificationsScreen(); 
      case 3: return _buildProfileScreen();
      default: return _buildIssuesList();
    }
  }

  Widget _buildProfileScreen() {
    // ... (existing _buildProfileScreen logic remains the same)
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final profile = userProfileService.currentUserProfile;
    
    if (profile == null && !userProfileService.isLoadingProfile) {
      // This might happen if the profile somehow becomes null after initial load
      // or if there was an error. The main loading is handled in the outer build method.
      return const Center(child: Text("Profile data not available. Please try again."));
    }
    if (profile == null && userProfileService.isLoadingProfile) {
        return const Center(child: CircularProgressIndicator());
    }
    if (profile == null) return const Center(child: Text("No profile data."));


    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48, 
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer, 
            backgroundImage: (profile.profilePhotoUrl != null && profile.profilePhotoUrl!.isNotEmpty) ? NetworkImage(profile.profilePhotoUrl!) : null,
            child: (profile.profilePhotoUrl == null || profile.profilePhotoUrl!.isEmpty) && (profile.username != null && profile.username!.isNotEmpty)
                ? Text(profile.username![0].toUpperCase(), style: const TextStyle(fontSize: 32)) 
                : null,
          ),
          const SizedBox(height: 16),
          Text(profile.username ?? "Official User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(profile.email ?? "No email", style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Text("Department: ${profile.department ?? "Not Assigned"}", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text("Designation: ${profile.designation ?? "Not Specified"}", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout), 
            label: const Text("Logout"), 
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut(context);
              // AuthWrapper in main.dart should handle navigation to role_selection
            }
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList() {
    // ... (existing _buildIssuesList logic remains the same)
    final userProfileService = Provider.of<UserProfileService>(context, listen: false); // listen:false is fine for one-time reads
    
    if (_departmentName == "Loading..." || (userProfileService.isLoadingProfile && _departmentIssuesStream == null)) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Loading dashboard...", style: TextStyle(fontSize: 16))]));
    }
    if (_departmentName == "Not Assigned") {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Your account is not yet assigned to a department. Please contact an administrator.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.orangeAccent))));
    }
    if (_departmentIssuesStream == null) {
        // This case should ideally be covered by the loading/error states above or after _setupStreamQuery is called.
        // If it's reached, it might mean the department name is set but stream setup failed or hasn't completed.
        _setupStreamQuery(); // Attempt to set up stream again if it's null
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
                            _buildPopupMenuItem('Resolved', issue.status),
                            _buildPopupMenuItem('Rejected', issue.status),
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
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha((0.4 * 255).round()),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (issue.urgency != null && issue.urgency!.isNotEmpty)
                          Chip(
                            avatar: Icon(Icons.priority_high_rounded, size: 15, color: _getUrgencyColor(issue.urgency)),
                            label: Text(issue.urgency!, style: TextStyle(fontSize: 11.5, color: _getUrgencyColor(issue.urgency), fontWeight: FontWeight.w500)),
                            backgroundColor: _getUrgencyColor(issue.urgency).withAlpha((0.15 * 255).round()),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (issue.tags != null && issue.tags!.isNotEmpty)
                          ...issue.tags!.map((tag) => Chip(
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
    // ... (existing _buildPopupMenuItem logic remains the same)
    return PopupMenuItem<String>(value: value, enabled: value != currentStatus, child: Text(value, style: TextStyle(color: value == currentStatus ? Colors.grey : null)));
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    // ... (existing _buildInfoChip logic remains the same)
     return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color.withAlpha((0.8 * 255).round())),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context); // Listen for changes
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Show loading indicator if the profile is loading and we don't have department name yet
    if (userProfileService.isLoadingProfile && _departmentName == "Loading...") {
      return Scaffold(
        appBar: AppBar(title: const Text("Loading Dashboard...")), 
        body: const Center(child: CircularProgressIndicator(semanticsLabel: "Loading profile..."))
      );
    }

    // If profile loading is done but current user is not an official, redirect.
    // This check should ideally be handled by AuthWrapper in main.dart, but it's a safeguard.
    if (!userProfileService.isLoadingProfile && !(userProfileService.currentUserProfile?.isOfficial ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) { // Ensure screen is still active
          Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
        }
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')), 
        body: const Center(child: Text('Redirecting...', style: TextStyle(fontSize: 16)))
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? (_departmentName == "Not Assigned" || _departmentName == "Loading..." ? "Official Dashboard" : '$_departmentName Issues') : 
          _selectedIndex == 1 ? "Department Statistics" :
          _selectedIndex == 2 ? "Alerts & Notifications" : // Updated title for Alerts tab
          "Profile", 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)
        ),
        actions: _selectedIndex == 0 ? [ // Show filter/sort only for Issues list
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            tooltip: 'Filter Issues',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort_by_alpha_rounded), 
            tooltip: 'Sort Issues',
            onPressed: _showSortOptions,
          ),
        ] : null, // No actions for other tabs for now
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if(mounted) setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColorDark, // Darker shade for selected
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active_outlined), label: 'Alerts'), // Changed label
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}
