// screens/main_app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'feed/issues_list_screen.dart';
import 'report/camera_capture_screen.dart'; // Entry point for reporting
import 'profile/account_screen.dart';
import '/utils/update_checker.dart';


class MainAppScaffold extends StatefulWidget {
  const MainAppScaffold({super.key});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> {
  int _selectedIndex = 0;
  User? _currentUser;

  static final List<Widget> _widgetOptions = <Widget>[
    const IssuesListScreen(),
    const CameraCaptureScreen(), // This will be the screen to start the reporting flow
    const Center(child: Text('Notifications (Future)')), // Placeholder for Notifications
    AccountScreen(key: UniqueKey()), // Ensure AccountScreen rebuilds if needed
  ];

 @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    // Listen to auth state changes to update UI if user logs out from AccountScreen
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        if (user == null) {
          // If user logs out, AuthWrapper in main.dart will handle navigation to HomeScreen
          // No explicit navigation needed here unless you want to pop all internal routes of MainAppScaffold
        }
      }
    });
    // Check for updates when app starts
    UpdateChecker.checkForUpdate(context);
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      // This case should ideally be handled by AuthWrapper navigating away.
      // But as a fallback, show loading or redirect.
      return const Scaffold(body: Center(child: CircularProgressIndicator( semanticsLabel: "Loading user data",)));
    }
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 0 ? Icons.home : Icons.home_outlined),
            label: '', // As per UI, no labels
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 1 ? Icons.camera_alt : Icons.camera_alt_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 2 ? Icons.notifications : Icons.notifications_outlined),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 3 ? Icons.person : Icons.person_outlined),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Colors.white,
        elevation: 8.0,
      ),
    );
  }
}