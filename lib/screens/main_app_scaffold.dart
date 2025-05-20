// lib/screens/main_app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Added for UserProfileService access
import '../services/user_profile_service.dart'; // Added
import 'feed/issues_list_screen.dart';
import 'report/camera_capture_screen.dart';
import 'profile/account_screen.dart';
import 'map/map_view_screen.dart'; // <-- NEW: Import for the map screen
import '../utils/update_checker.dart';
import 'dart:developer' as developer;


class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> with WidgetsBindingObserver { // Added WidgetsBindingObserver
  int _selectedIndex = 0;
  User? _currentUser;
  bool _hasCheckedUpdate = false; // To ensure update check runs once per resume or init

  // Updated _widgetOptions to include MapViewScreen
  static final List<Widget> _widgetOptions = <Widget>[
    const IssuesListScreen(),
    const CameraCaptureScreen(),
    const MapViewScreen(), // <-- NEW: Map Screen Added
    const Center(child: Text('Notifications (Future)')),
    AccountScreen(key: UniqueKey()),
  ];

 @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Register observer
    _currentUser = FirebaseAuth.instance.currentUser;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _performInitialChecks();
      }
    });

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        if (user == null && ModalRoute.of(context)?.settings.name == '/app') {
          // If user logs out from AccountScreen and we are still on /app route
          // AuthWrapper in main.dart should handle navigation to RoleSelectionScreen
          // but as a defensive measure, we can log or prepare for it.
          developer.log("MainAppScaffold: User logged out, AuthWrapper should navigate.", name: "MainAppScaffold");
        }
      }
    });
  }

  Future<void> _performInitialChecks() async {
    // Store the service reference before any async operations
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    
    // Check for updates
    if (mounted && !_hasCheckedUpdate) {
      developer.log("MainAppScaffold: Performing initial update check.", name: "MainAppScaffold");
      await UpdateChecker.checkForUpdate(context);
      if(mounted) setState(() => _hasCheckedUpdate = true);
    }

    // Ensure user profile is loaded if not already
    if (!mounted) return; // Add early return if widget is disposed
    if (userProfileService.currentUserProfile == null && !userProfileService.isLoadingProfile && _currentUser != null) {
      developer.log("MainAppScaffold: Initial profile fetch triggered.", name: "MainAppScaffold");
      await userProfileService.fetchAndSetCurrentUserProfile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      developer.log("MainAppScaffold: App Resumed.", name: "MainAppScaffold");
      // Reset flag and check for updates again if app was paused for a while
      // More sophisticated logic might be needed if you want to avoid too frequent checks
      if (mounted) {
         _hasCheckedUpdate = false; // Reset to allow check on resume
         _performInitialChecks(); // Perform checks again on resume
      }
    } else if (state == AppLifecycleState.paused) {
      developer.log("MainAppScaffold: App Paused.", name: "MainAppScaffold");
      // No action needed on pause typically, but you could set _hasCheckedUpdate to false here
      // if you want to ensure an update check on every resume.
      // For now, _performInitialChecks on resume will handle it.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Unregister observer
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This check is important. If _currentUser becomes null (e.g., due to external logout/token expiry),
    // AuthWrapper in main.dart should handle redirecting.
    // Showing a loading indicator here prevents potential errors if _widgetOptions
    // try to access user-specific data before redirection.
    if (_currentUser == null) {
      developer.log("MainAppScaffold: Current user is null, showing loading. AuthWrapper should redirect.", name: "MainAppScaffold");
      return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: "Authenticating...")));
    }

    return Scaffold(
      body: IndexedStack( // Using IndexedStack to preserve state of screens
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 0 ? Icons.list_alt_rounded : Icons.list_alt_outlined), // Changed Home to List
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 1 ? Icons.camera_alt : Icons.camera_alt_outlined),
            label: '',
          ),
          BottomNavigationBarItem( // <-- NEW: Map Item
            icon: Icon(_selectedIndex == 2 ? Icons.map : Icons.map_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 3 ? Icons.notifications : Icons.notifications_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 4 ? Icons.person : Icons.person_outlined),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600], // Slightly darker grey for better visibility
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Colors.white,
        elevation: 8.0,
      ),
    );
  }
}
