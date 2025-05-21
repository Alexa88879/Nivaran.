// lib/screens/main_app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/user_profile_service.dart';
import 'feed/issues_list_screen.dart';
import 'report/camera_capture_screen.dart';
import 'profile/account_screen.dart';
import 'map/map_view_screen.dart';
import 'notifications/notifications_screen.dart'; // <-- NEW: Import for NotificationsScreen
import '../utils/update_checker.dart';
import 'dart:developer' as developer;

class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  User? _currentUser;
  bool _hasCheckedUpdate = false;

  // Updated _widgetOptions to include NotificationsScreen
  static final List<Widget> _widgetOptions = <Widget>[
    const IssuesListScreen(),
    const CameraCaptureScreen(),
    const MapViewScreen(),
    const NotificationsScreen(), // <-- NEW: Notifications Screen Added
    AccountScreen(key: UniqueKey()), // Ensure AccountScreen rebuilds if needed
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
          developer.log("MainAppScaffold: User logged out, AuthWrapper should navigate.", name: "MainAppScaffold");
        }
      }
    });
  }

  Future<void> _performInitialChecks() async {
    // Store the context and service reference before any async operations
    if (!mounted) return;
    final currentContext = context;
    final userProfileService = Provider.of<UserProfileService>(currentContext, listen: false);

    if (mounted && !_hasCheckedUpdate) {
      developer.log("MainAppScaffold: Performing initial update check.", name: "MainAppScaffold");
      if (!mounted) return;
      await UpdateChecker.checkForUpdate(currentContext);
      if(mounted) setState(() => _hasCheckedUpdate = true);
    }
    
    // Fetch the user's profile if it's not already loaded
    if (!mounted) return;
    if (_currentUser != null && userProfileService.currentUserProfile?.uid != _currentUser!.uid && !userProfileService.isLoadingProfile) {
        developer.log("MainAppScaffold: Initial profile fetch triggered because current user profile doesn't match auth user or is null.", name: "MainAppScaffold");
        await userProfileService.fetchAndSetCurrentUserProfile();
    } else if (_currentUser != null && userProfileService.currentUserProfile == null && !userProfileService.isLoadingProfile) {
        developer.log("MainAppScaffold: Current user exists but profile is null, attempting fetch.", name: "MainAppScaffold");
        await userProfileService.fetchAndSetCurrentUserProfile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      developer.log("MainAppScaffold: App Resumed.", name: "MainAppScaffold");
      if (mounted) {
         _hasCheckedUpdate = false; 
         _performInitialChecks(); 
      }
    } else if (state == AppLifecycleState.paused) {
      developer.log("MainAppScaffold: App Paused.", name: "MainAppScaffold");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      developer.log("MainAppScaffold: Current user is null, showing loading. AuthWrapper should redirect.", name: "MainAppScaffold");
      return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: "Authenticating...")));
    }

    // Check if UserProfile is loading. If so, show loading indicator for the whole scaffold.
    // This prevents individual screens from trying to access a null profile prematurely.
    final userProfileService = Provider.of<UserProfileService>(context);
    if (userProfileService.isLoadingProfile && userProfileService.currentUserProfile == null) {
        developer.log("MainAppScaffold: UserProfileService is loading initial profile. Showing loading screen.", name: "MainAppScaffold");
        return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: "Loading user profile...")));
    }


    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 0 ? Icons.list_alt_rounded : Icons.list_alt_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 1 ? Icons.camera_alt : Icons.camera_alt_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 2 ? Icons.map : Icons.map_outlined),
            label: '',
          ),
          BottomNavigationBarItem( // <-- NEW: Notifications Tab
            // TODO: Add badge for unread notifications later
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
        unselectedItemColor: Colors.grey[600],
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
