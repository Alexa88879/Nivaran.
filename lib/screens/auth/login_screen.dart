// lib/screens/auth/login_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';
import '../../widgets/social_button.dart';
import '../../common/app_logo.dart';
import '../../models/app_user_model.dart';
import 'dart:developer' as developer;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingGoogle = false;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);

    try {
      await authService.signInWithEmail( // AuthService handles actual sign-in and profile fetching
        context, 
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (mounted && userProfileService.currentUserProfile != null) {
         // Check if this user is an official and redirect accordingly if needed
         // For citizen login, we go to /app. Official login screen handles /official_dashboard
         if (userProfileService.currentUserProfile!.isOfficial) {
            developer.log("LoginScreen: Official user detected logging into citizen portal. Redirecting to official dashboard.", name:"LoginScreen");
            // This scenario should ideally be handled by distinct login pages or role check *before* navigation.
            // For now, if an official accidentally uses citizen login and succeeds, send to their dash.
            Navigator.of(context).pushNamedAndRemoveUntil('/official_dashboard', (Route<dynamic> route) => false);
         } else {
            Navigator.of(context).pushNamedAndRemoveUntil('/app', (Route<dynamic> route) => false);
         }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful but failed to retrieve user profile. Please try again.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = "Login failed. Please check your credentials.";
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
          errorMessage = "Invalid email or password. Please try again.";
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      developer.log("Login error: $e", name: "LoginScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred during login.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!mounted) return;
    setState(() => _isLoadingGoogle = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);

    try {
      UserCredential? userCredential = await authService.signInWithGoogle(context);

      if (userCredential != null && userCredential.user != null) {
        final user = userCredential.user!;
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDocSnapshot = await userDocRef.get();

        String finalUsername = user.displayName?.replaceAll(' ', '').toLowerCase() ?? user.email!.split('@')[0];

        if (!userDocSnapshot.exists) { 
          if (!mounted) return;
          // Prompt for username only if it's a truly new user to our system
          final String? chosenUsername = await _promptForUsername(context, finalUsername);

          if (chosenUsername == null || chosenUsername.trim().isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Username is required for new Google Sign-In users.')),
              );
            }
            if (mounted) await authService.signOut(context);
            setState(() => _isLoadingGoogle = false);
            return;
          }
          finalUsername = chosenUsername.trim();

          // Optional: Add check for username uniqueness against 'users' collection
          // QuerySnapshot usernameCheck = await FirebaseFirestore.instance
          //   .collection('users')
          //   .where('username', isEqualTo: finalUsername)
          //   .limit(1)
          //   .get();
          // if (usernameCheck.docs.isNotEmpty) { /* handle taken username */ }


          AppUser newUser = AppUser(
            uid: user.uid,
            email: user.email,
            username: finalUsername,
            fullName: user.displayName ?? finalUsername,
            role: 'user', // New Google sign-ins are citizens by default
            createdAt: Timestamp.now(),
            profilePhotoUrl: user.photoURL,
          );
          await userDocRef.set(newUser.toMap());
        }
        
        // Crucial: Ensure profile with claims is loaded
        await userProfileService.fetchAndSetCurrentUserProfile();

        if (mounted && userProfileService.currentUserProfile != null) {
            if (userProfileService.currentUserProfile!.isOfficial) {
                 developer.log("LoginScreen: Official user detected logging in via Google to citizen portal. Redirecting.", name:"LoginScreen");
                Navigator.of(context).pushNamedAndRemoveUntil('/official_dashboard', (Route<dynamic> route) => false);
            } else {
                Navigator.of(context).pushNamedAndRemoveUntil('/app', (Route<dynamic> route) => false);
            }
        } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Google Sign-In successful but failed to finalize profile.")),
           );
        }

      } else if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In was cancelled or failed.")),
        );
      }
    } catch (e,s) {
      developer.log("Google login error: $e", name: "LoginScreen", stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In failed. An unexpected error occurred.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  Future<String?> _promptForUsername(BuildContext context, String suggestedUsername) {
    final TextEditingController usernamePopupController = TextEditingController(text: suggestedUsername);
    final GlobalKey<FormState> popupFormKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Choose a Username', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Form(
            key: popupFormKey,
            child: CustomTextField( 
              controller: usernamePopupController,
              hintText: 'Enter a unique username',
              prefixIconData: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Username cannot be empty.';
                if (value.trim().length < 3) return 'Min 3 characters.';
                if (value.trim().contains(' ')) return 'Username cannot contain spaces.';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(null); // User cancelled
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () {
                if (popupFormKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(usernamePopupController.text.trim());
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) { // Use trim()
      return 'Please enter your email.';
    }
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) { // No trim for password during validation check
      return 'Please enter your password.';
    }
    return null; // PDF doesn't specify length for login, only for signup
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar( 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AppLogo(logoSymbolSize: 28, showAppName: false), // "N" logo
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: screenHeight * 0.04),
                  Text(
                    'Welcome back', // PDF Page 4 Title
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Text(
                    'Login with your email or Google account', // PDF Page 4 Subtitle
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.grey[600]),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'email@domain.com', // PDF Page 5 hint
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    focusNode: _emailFocusNode,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_passwordFocusNode);
                    },
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'password', // PDF Page 5 hint
                    obscureText: true,
                    validator: _validatePassword,
                    focusNode: _passwordFocusNode,
                    onFieldSubmitted: (_) => _loginUser(),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  AuthButton(
                    text: 'Continue', // PDF Page 5 Button ("Continue" or "Login" from Page 4)
                    onPressed: _loginUser,
                    isLoading: _isLoading,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Row(
                    children: <Widget>[
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: Text('or', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  SocialButton(
                    text: 'Continue with Google',
                    iconAssetPath: 'assets/icon/google.png', 
                    onPressed: _loginWithGoogle,
                    isLoading: _isLoadingGoogle,
                  ),
                  SizedBox(height: screenHeight * 0.06),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 10.0),
                     child: Text.rich(
                      TextSpan(
                        text: 'By clicking continue, you agree to our ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        children: <TextSpan>[
                          TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()..onTap = () {  },
                              ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()..onTap = () {  },
                              ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                   ),
                  SizedBox(height: screenHeight * 0.02),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: Colors.grey[700])),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/signup');
                        },
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                   SizedBox(height: screenHeight * 0.02),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}