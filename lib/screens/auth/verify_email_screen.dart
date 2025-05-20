// lib/screens/auth/verify_email_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../common/app_logo.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/auth_button.dart';
import 'dart:developer' as developer;

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _timer;
  bool _isSendingVerification = false;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    // Start a timer to periodically check email verification status
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkEmailVerified(autoCheck: true);
    });
    // Initial check, in case user comes back to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmailVerified(autoCheck: true, initialCheck: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified({bool autoCheck = false, bool initialCheck = false}) async {
    if (!mounted || _isCheckingStatus && !initialCheck) return;

    if (!autoCheck) {
      setState(() => _isCheckingStatus = true);
    }

    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload(); // Crucial: reload to get the latest user state
      user = _auth.currentUser; // Re-fetch user after reload

      if (user != null && user.emailVerified) {
        _timer?.cancel();
        developer.log("Email verified for: ${user.email}", name: "VerifyEmailScreen");
        if (mounted) {
          // Fetch profile to determine if user is official or citizen for correct navigation
          final userProfileService = Provider.of<UserProfileService>(context, listen: false);
          await userProfileService.fetchAndSetCurrentUserProfile();
          
          if (!mounted) return;

          if (userProfileService.currentUserProfile != null) {
            if (userProfileService.currentUserProfile!.isOfficial) {
              // If official, they might have signed up but not entered details yet.
              // Check if details like department are present.
              // This logic might need refinement based on your exact flow for officials.
              if (userProfileService.currentUserProfile!.department == null || userProfileService.currentUserProfile!.department!.isEmpty) {
                 developer.log("Official email verified, navigating to details entry.", name: "VerifyEmailScreen");
                 Navigator.of(context).pushNamedAndRemoveUntil('/official_details_entry', (route) => false);
              } else {
                developer.log("Official email verified, navigating to official dashboard.", name: "VerifyEmailScreen");
                Navigator.of(context).pushNamedAndRemoveUntil('/official_dashboard', (route) => false);
              }
            } else {
              developer.log("Citizen email verified, navigating to app.", name: "VerifyEmailScreen");
              Navigator.of(context).pushNamedAndRemoveUntil('/app', (route) => false);
            }
          } else {
            // Fallback if profile couldn't be loaded, though unlikely if user exists
            developer.log("Email verified, but profile not loaded. Navigating to role selection.", name: "VerifyEmailScreen");
            Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
          }
        }
      } else if (!autoCheck && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not yet verified. Please check your inbox.')),
        );
      }
    }
    if (!autoCheck && mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!mounted || _isSendingVerification) return;
    setState(() => _isSendingVerification = true);
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email resent! Please check your inbox.')),
          );
        }
      } catch (e) {
        developer.log("Error resending verification email: $e", name: "VerifyEmailScreen");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resend email: ${e.toString()}')),
          );
        }
      }
    } else {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not logged in. Cannot resend email.')),
          );
        }
    }
    if (mounted) {
      setState(() => _isSendingVerification = false);
    }
  }

  Future<void> _logoutAndGoToRoleSelection() async {
    _timer?.cancel();
    if (mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut(context); // This also clears UserProfileService
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;
    final String userEmail = currentUser?.email ?? "your email address";
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const AppLogo(logoSymbolSize: 28, showAppName: false),
        centerTitle: true,
        automaticallyImplyLeading: false, // No back button
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: screenHeight * 0.05),
                Icon(Icons.mark_email_read_outlined, size: screenWidth * 0.25, color: Theme.of(context).primaryColor),
                SizedBox(height: screenHeight * 0.03),
                Text(
                  'Verify Your Email',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                SizedBox(height: screenHeight * 0.015),
                Text(
                  'We\'ve sent a verification link to\n$userEmail.\nPlease check your inbox (and spam folder) and click the link to activate your account.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.grey[700], height: 1.5),
                ),
                SizedBox(height: screenHeight * 0.05),
                AuthButton(
                  text: 'Check Verification Status',
                  onPressed: () => _checkEmailVerified(autoCheck: false),
                  isLoading: _isCheckingStatus,
                ),
                SizedBox(height: screenHeight * 0.02),
                OutlinedButton.icon(
                  icon: _isSendingVerification 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.outgoing_mail, color: Theme.of(context).colorScheme.secondary),
                  label: Text('Resend Verification Email', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).colorScheme.secondary.withAlpha(150)),
                     minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _isSendingVerification ? null : _resendVerificationEmail,
                ),
                SizedBox(height: screenHeight * 0.04),
                TextButton(
                  onPressed: _logoutAndGoToRoleSelection,
                  child: Text(
                    'Use a different email or go back',
                    style: TextStyle(color: Colors.grey[600], decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
