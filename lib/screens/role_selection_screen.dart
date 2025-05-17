// lib/screens/role_selection_screen.dart
import 'package:flutter/material.dart';
import '../common/app_logo.dart';
import '../widgets/auth_button.dart'; 
import '../utils/update_checker.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> with WidgetsBindingObserver {
  bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial update check when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateChecker.checkForUpdate(context);
        _hasCheckedUpdate = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasCheckedUpdate) {
      // Only check for updates when app is resumed and hasn't checked yet
      if (mounted) {
        UpdateChecker.checkForUpdate(context);
        _hasCheckedUpdate = true;
      }
    } else if (state == AppLifecycleState.paused) {
      // Reset the flag when app is paused, so it will check again when resumed
      _hasCheckedUpdate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08, vertical: screenHeight * 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: screenHeight * 0.12), 
                const AppLogo(logoSymbolSize: 70, showAppName: true, appNameFontSize: 32),
                SizedBox(height: screenHeight * 0.15), 
                
                AuthButton(
                  text: 'Government Employee',
                  onPressed: () {
                    Navigator.pushNamed(context, '/auth_options', arguments: 'official');
                  },
                ),
                SizedBox(height: screenHeight * 0.015), // Reduced space for "or"
                _buildOrDivider(context),
                SizedBox(height: screenHeight * 0.015),
                AuthButton(
                  text: 'Citizen',
                  onPressed: () {
                    Navigator.pushNamed(context, '/auth_options', arguments: 'citizen');
                  },
                ),
                SizedBox(height: screenHeight * 0.015),
                _buildOrDivider(context),
                SizedBox(height: screenHeight * 0.015),
                AuthButton( 
                  text: 'Public Dashboard',
      
                  backgroundColor: Colors.grey.shade200,
                  textColor: Colors.black,
                  onPressed: () {
                    Navigator.pushNamed(context, '/public_dashboard');
                  },
                ),
                const Spacer(), 
                 Padding(
                   padding: const EdgeInsets.only(bottom: 20.0),
                   child: Text(
                    "NIVARAN - Your Voice, Our Action.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                   ),
                 )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'or',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// Widget _buildOrDivider(BuildContext context) {
//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 8.0),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           'or',
//           style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//         ),
//       ],
//     ),
//   );
// }
