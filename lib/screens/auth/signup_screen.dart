// lib/screens/auth/signup_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';
import '../../common/app_logo.dart';
import '../../models/app_user_model.dart';
import 'dart:developer' as developer;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _signUpUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    try {
      
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        AppUser newUser = AppUser(
          uid: userCredential.user!.uid,
          email: email,
          username: username, // This is the 'Username' field from PDF Page 3
          fullName: username, // For citizen, username can serve as full name initially
          role: 'user',
          createdAt: Timestamp.now(),
          // Other fields like mobileNo, employeeId are null for citizen signup via this form
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(newUser.uid)
            .set(newUser.toMap());

        if (mounted) {
          // After creating the user and their Firestore doc, fetch the full profile
          await userProfileService.fetchAndSetCurrentUserProfile();
          if (userProfileService.currentUserProfile != null) {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/app', (Route<dynamic> route) => false);
            }
          } else {
            // This should ideally not happen if fetch is successful after doc creation
            developer.log("SignupScreen: Profile not loaded after creating user doc.", name: "SignUpScreen");
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Account created, but profile failed to load. Please try logging in.")),
            );
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = "Sign up failed. Please try again.";
        if (e.code == 'email-already-in-use') {
          errorMessage = 'This email address is already in use. Please try logging in.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e, s) {
      developer.log("Sign up error: $e", name: "SignUpScreen", error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred during sign up.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter a username.';
    if (value.trim().length < 3) return 'Username must be at least 3 characters.';
    // Example: Allow alphanumeric and underscore, no spaces
    // if (!RegExp(r"^[a-zA-Z0-9_]+$").hasMatch(value.trim())) return 'Username can only contain letters, numbers, and underscores.';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email.';
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
    if (!emailRegex.hasMatch(value.trim())) return 'Please enter a valid email address.';
    return null;
  }
  
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password.';
    if (value.length < 6) return 'Password must be at least 6 characters long.';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
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
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Create your account', // PDF Page 3 Title
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Text(
                    // Subtitle adjusted as Google sign-in is removed for this screen
                    'Sign up with your email', 
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.grey[600]),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  CustomTextField(
                    controller: _usernameController,
                    hintText: 'Username', 
                    prefixIconData: Icons.person_outline, // Icon next to label (field hint)
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    validator: _validateUsername,
                    focusNode: _usernameFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Email', 
                    prefixIconData: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    focusNode: _emailFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'Password', 
                    obscureText: true,
                    prefixIconData: Icons.lock_outline,
                    validator: _validatePassword,
                    focusNode: _passwordFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPasswordFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password', 
                    obscureText: true,
                    prefixIconData: Icons.lock_outline,
                    validator: _validateConfirmPassword,
                    focusNode: _confirmPasswordFocusNode,
                    onFieldSubmitted: (_) => _signUpUser(),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  AuthButton(
                    text: 'Sign Up', 
                    onPressed: _signUpUser,
                    isLoading: _isLoading,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  // "or" and "Continue with Google" are REMOVED for Citizen Signup
                  Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
                     child: Text.rich(
                        TextSpan(
                          text: 'By creating an account, you agree to our ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          children: <TextSpan>[
                            TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = () {},
                                ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = () { },
                                ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                   ),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? ", style: TextStyle(color: Colors.grey[700])),
                      GestureDetector(
                        onTap: () {
                           Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Text(
                          'Login',
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