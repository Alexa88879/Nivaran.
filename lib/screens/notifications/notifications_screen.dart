// lib/screens/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../services/user_profile_service.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Stream<List<NotificationModel>>? _notificationsStream;
  bool _isUserProfileAvailable = false; // To track if we can attempt to load notifications

  @override
  void initState() {
    super.initState();
    // Defer stream setup until after the first frame and when UserProfileService is likely ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check UserProfileService status before setting up the stream
        final userProfileService = Provider.of<UserProfileService>(context, listen: false);
        if (userProfileService.currentUserProfile != null) {
          setState(() {
            _isUserProfileAvailable = true;
          });
          _setupNotificationsStream();
        } else if (!userProfileService.isLoadingProfile) {
          // Profile is null and not loading, likely user is logged out or error
          setState(() {
            _isUserProfileAvailable = false;
          });
           developer.log("NotificationsScreen initState: User profile null and not loading.", name: "NotificationsScreen");
        }
        // If isLoadingProfile is true, the build method will show a loader
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This might be called if UserProfileService notifies changes.
    // Re-evaluate if stream needs to be set up.
    final userProfileService = Provider.of<UserProfileService>(context, listen: false); // listen:false is fine here
    if (userProfileService.currentUserProfile != null && !_isUserProfileAvailable) {
      developer.log("NotificationsScreen didChangeDependencies: User profile became available. Setting up stream.", name: "NotificationsScreen");
      if (mounted) {
        setState(() {
          _isUserProfileAvailable = true;
        });
        _setupNotificationsStream();
      }
    } else if (userProfileService.currentUserProfile == null && _isUserProfileAvailable) {
       developer.log("NotificationsScreen didChangeDependencies: User profile became null. Clearing stream.", name: "NotificationsScreen");
       if (mounted) {
         setState(() {
           _isUserProfileAvailable = false;
           _notificationsStream = Stream.value([]); // Clear stream
         });
       }
    }
  }


  void _setupNotificationsStream() {
    if (!mounted || !_isUserProfileAvailable) return; // Don't proceed if profile not available

    final userId = Provider.of<UserProfileService>(context, listen: false).currentUserProfile?.uid;

    if (userId == null) {
      developer.log("NotificationsScreen _setupNotificationsStream: User ID is null, cannot fetch notifications.", name: "NotificationsScreen");
      if (mounted) {
        setState(() {
          _notificationsStream = Stream.value([]);
        });
      }
      return;
    }

    developer.log("NotificationsScreen: Setting up stream for user $userId", name: "NotificationsScreen");
    if (mounted) { // Redundant check, but safe
      setState(() {
        _notificationsStream = FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .map((snapshot) => snapshot.docs
                .map((doc) => NotificationModel.fromFirestore(doc))
                .toList())
            .handleError((error) {
          developer.log("Error in notifications stream: $error", name: "NotificationsScreen");
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error loading notifications: ${error.toString()}"))
            );
          }
          return <NotificationModel>[];
        });
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notification.id)
          .update({'isRead': true});
    } catch (e) {
      developer.log("Error marking notification as read: $e", name: "NotificationsScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to mark as read: ${e.toString()}")),
        );
      }
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    developer.log("Notification tapped: ${notification.title}, NavigateTo: ${notification.navigateTo}, IssueID: ${notification.issueId}", name: "NotificationsScreen");
    
    if(!mounted) return;

    _markAsRead(notification);

    final String? navigateTo = notification.navigateTo;
    final String? issueId = notification.issueId;

    // Use a local variable for context to ensure it's valid at the point of navigation.
    final currentContext = context; 

    if (navigateTo != null && navigateTo.isNotEmpty) {
        if (navigateTo == '/issue_details' && issueId != null && issueId.isNotEmpty) {
            developer.log("Navigating to issue details: $issueId", name: "NotificationsScreen");
            Navigator.pushNamed(currentContext, '/issue_details', arguments: issueId);
        } else if (navigateTo == '/official_dashboard' || navigateTo == '/app') {
             developer.log("Navigating to main dashboard: $navigateTo", name: "NotificationsScreen");
             Navigator.pushNamedAndRemoveUntil(currentContext, navigateTo, (route) => false);
        }
         else {
            developer.log("Navigating to general route: $navigateTo", name: "NotificationsScreen");
            Navigator.pushNamed(currentContext, navigateTo);
        }
    } else if (issueId != null && issueId.isNotEmpty) {
        developer.log("No 'navigateTo' but issueId is present. Navigating to /issue_details with $issueId", name: "NotificationsScreen");
        Navigator.pushNamed(currentContext, '/issue_details', arguments: issueId);
    }
     else {
        developer.log("No specific navigation route or issueId found for this notification.", name: "NotificationsScreen");
    }
}


  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context); // Listen to changes for loading state

    if (userProfileService.isLoadingProfile) {
        return Scaffold(
            appBar: AppBar(title: const Text("Notifications")),
            body: const Center(child: CircularProgressIndicator(semanticsLabel: "Loading user data..."))
        );
    }
    
    if (userProfileService.currentUserProfile == null) {
      // AuthWrapper should handle navigation if user logs out.
      // This screen just shows a message if it's somehow still displayed.
      developer.log("NotificationsScreen build: User profile null and not loading. AuthWrapper should redirect.", name: "NotificationsScreen");
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Please log in to see notifications.")),
      );
    }

    // At this point, currentUserProfile is not null and not loading.
    // If _notificationsStream is still null, it means _setupNotificationsStream hasn't run or completed yet
    // or _isUserProfileAvailable wasn't set correctly.
    // The didChangeDependencies should handle setting up the stream when profile becomes available.
    if (_notificationsStream == null && _isUserProfileAvailable) {
        // This might happen if initState's postFrameCallback didn't set it up due to timing.
        // Or if didChangeDependencies was called and profile was available but stream wasn't set.
        _setupNotificationsStream(); // Attempt setup
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationsStream ?? Stream.value([]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !(snapshot.hasData || snapshot.hasError)) {
            return const Center(child: CircularProgressIndicator(semanticsLabel: "Loading notifications..."));
          }
          if (snapshot.hasError) {
            developer.log("Error in StreamBuilder: ${snapshot.error}", name: "NotificationsScreen");
            return Center(child: Text("Error loading notifications: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column( // FIXED: Removed const
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text("No notifications yet.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: notification.isRead
                      ? Colors.grey.shade200
                      : Theme.of(context).colorScheme.secondary.withAlpha(30),
                  child: Icon(
                    _getIconForNotificationType(notification.type),
                    color: notification.isRead ? Colors.grey.shade500 : Theme.of(context).colorScheme.secondary,
                    size: 22,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                    color: notification.isRead ? Colors.grey.shade700 : Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yy, hh:mm a').format(notification.createdAt.toDate()),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                trailing: notification.isRead ? null : Icon(Icons.circle, color: Theme.of(context).colorScheme.secondary, size: 10),
                onTap: () => _handleNotificationTap(notification),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'status_update':
        return Icons.flag_circle_outlined;
      case 'new_comment':
        return Icons.chat_bubble_outline_rounded;
      case 'issue_resolved':
        return Icons.check_circle_outline_rounded;
      case 'new_issue_for_official':
        return Icons.assignment_late_outlined;
      case 'admin_message':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }
}
