// lib/screens/official/official_signup_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../common/app_logo.dart';
import '../../models/app_user_model.dart';
import '../../services/user_profile_service.dart'; // Keep for potential future use, though not directly used in _signUpOfficial now
import '../../widgets/auth_button.dart';
import '../../widgets/custom_text_field.dart';
import 'dart:developer' as developer;

class OfficialSignupScreen extends StatefulWidget {
  const OfficialSignupScreen({super.key});

  @override
  State<OfficialSignupScreen> createState() => _OfficialSignupScreenState();
}

class _OfficialSignupScreenState extends State<OfficialSignupScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _officialEmailController = TextEditingController();
  final TextEditingController _mobileNoController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _mobileNoFocusNode = FocusNode();
  final FocusNode _employeeIdFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _fullNameController.dispose();
    _officialEmailController.dispose();
    _mobileNoController.dispose();
    _employeeIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _mobileNoFocusNode.dispose();
    _employeeIdFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _signUpOfficial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    // UserProfileService is not directly used here for profile fetching after signup,
    // as that will happen after email verification and potentially details entry.
    // final userProfileService = Provider.of<UserProfileService>(context, listen: false); 
    final String fullName = _fullNameController.text.trim();
    final String email = _officialEmailController.text.trim();
    final String password = _passwordController.text.trim(); 
    final String mobileNo = _mobileNoController.text.trim();
    final String employeeId = _employeeIdController.text.trim();

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // DO NOT send verification email here. It will be sent after OfficialDetailsEntryScreen.

        AppUser newOfficialUser = AppUser(
          uid: firebaseUser.uid,
          email: email,
          username: fullName, 
          fullName: fullName,
          mobileNo: mobileNo,
          employeeId: employeeId,
          role: 'official', 
          createdAt: Timestamp.now(),
          // Other fields like designation, department will be added in the next screen
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(newOfficialUser.uid)
            .set(newOfficialUser.toMap());
        
        // No need to call fetchAndSetCurrentUserProfile here.
        // The user is created, now they need to enter more details.

        if (mounted) {
          // Navigate to the Official Details Entry Screen
          Navigator.of(context).pushReplacementNamed('/official_details_entry');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = "Official registration failed.";
        if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already registered. Please try logging in or use a different email.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak (minimum 6 characters).';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e, s) {
      developer.log("Official Signup Error: $e", name: "OfficialSignupScreen", error:e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred during registration.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    return null;
  }
   String? _validateFullName(String? value) {
     if (value == null || value.trim().isEmpty) return 'Full Name is required.';
     if (value.trim().length < 3) return 'Full name seems too short.';
     return null;
  }
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Official Email is required.';
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
    if (!emailRegex.hasMatch(value.trim())) return 'Please enter a valid email address.';
    return null;
  }
   String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) return 'Mobile number is required.';
    if (!RegExp(r"^\+?[0-9]{10,14}$").hasMatch(value.trim())) return 'Enter a valid mobile number.';
    return null;
  }
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
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
        title: const AppLogo(logoSymbolSize: 28, showAppName: false),
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
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'Official Sign up', 
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Enter your details for sign up', 
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.grey[600]),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  CustomTextField(
                    controller: _fullNameController,
                    hintText: 'full name', 
                    textCapitalization: TextCapitalization.words,
                    validator: _validateFullName,
                    focusNode: _fullNameFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  CustomTextField(
                    controller: _officialEmailController,
                    hintText: 'official email',
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    focusNode: _emailFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_mobileNoFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  CustomTextField(
                    controller: _mobileNoController,
                    hintText: 'mobile no',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validateMobile,
                    focusNode: _mobileNoFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_employeeIdFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  CustomTextField(
                    controller: _employeeIdController,
                    hintText: 'employee id',
                    validator: (val) => _validateNotEmpty(val, "Employee ID"),
                    focusNode: _employeeIdFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'Create Password', 
                    obscureText: true,
                    validator: _validatePassword,
                    focusNode: _passwordFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPasswordFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    obscureText: true,
                    validator: _validateConfirmPassword,
                    focusNode: _confirmPasswordFocusNode,
                    onFieldSubmitted: (_) => _signUpOfficial(),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  AuthButton(
                    text: 'Continue to Details', // Changed button text
                    onPressed: _signUpOfficial,
                    isLoading: _isLoading,
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
                     child: Text.rich(
                        TextSpan(
                          text: 'By clicking continue, you confirm you are an authorized government employee and agree to our ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          children: <TextSpan>[
                            TextSpan(
                                text: 'Official Terms of Service',
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
                      Text("Already registered as an official? ", style: TextStyle(color: Colors.grey[700])),
                      GestureDetector(
                        onTap: () {
                           Navigator.pushReplacementNamed(context, '/official_login');
                        },
                        child: Text(
                          'Login Here',
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
