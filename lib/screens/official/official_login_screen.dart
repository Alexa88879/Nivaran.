// lib/screens/official/official_login_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';
import '../../widgets/social_button.dart';
import '../../common/app_logo.dart';
// import '../../models/app_user_model.dart';
import 'dart:developer' as developer;

class OfficialLoginScreen extends StatefulWidget {
  const OfficialLoginScreen({super.key});

  @override
  State<OfficialLoginScreen> createState() => _OfficialLoginScreenState();
}

class _OfficialLoginScreenState extends State<OfficialLoginScreen> {
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

  Future<void> _loginOfficial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);

    try {
      await authService.signInWithEmail(
        context, // For UserProfileService to be called within AuthService
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted && userProfileService.currentUserProfile != null) {
        if (userProfileService.currentUserProfile!.isOfficial) {
          Navigator.of(context).pushNamedAndRemoveUntil('/official_dashboard', (Route<dynamic> route) => false);
        } else if (userProfileService.currentUserProfile!.isPendingOfficial) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Your official account is pending admin verification.")),
          );
          // Optionally sign them out or redirect to a waiting screen
          final navigator = Navigator.of(context);
          await authService.signOut(context);
          if (!mounted) return;
          navigator.pushNamedAndRemoveUntil('/role_selection', (route) => false);
          // Back to start
        }
         else {
          await authService.signOut(context); 
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Access Denied. This portal is for authorized officials only.")),
          );
        }
      } else if (mounted) {
        // This means login might have passed auth but profile didn't load or user is null
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login succeeded but failed to verify official status. Please try again.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = "Official login failed.";
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-email') {
          errorMessage = "Invalid official email or password.";
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      developer.log("Official Login error: $e", name: "OfficialLoginScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred during official login.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogleOfficial() async {
    if (!mounted) return;
    setState(() => _isLoadingGoogle = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);

    try {
      UserCredential? userCredential = await authService.signInWithGoogle(context);

      if (userCredential != null && userCredential.user != null) {
        await userProfileService.fetchAndSetCurrentUserProfile(); 

        if (mounted && userProfileService.currentUserProfile != null) {
          if (userProfileService.currentUserProfile!.isOfficial) {
            Navigator.of(context).pushNamedAndRemoveUntil('/official_dashboard', (Route<dynamic> route) => false);
          } else if (userProfileService.currentUserProfile!.isPendingOfficial) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Google Sign-In successful. Your official account is pending admin verification.")),
            );
            await authService.signOut(context);
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
            }
          }
          else {
            
            await authService.signOut(context);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
            content: Text("Google account not recognized as an official. Please use official credentials or contact admin."),
  ),
);

          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Google Sign-In successful but failed to verify official status.")),
          );
        }
      } else if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In was cancelled or failed.")),
        );
      }
    } catch (e) {
      developer.log("Official Google login error: $e", name: "OfficialLoginScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In for officials failed.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }
  
  String? _validateEmail(String? value) { 
    if (value == null || value.trim().isEmpty) return 'Please enter your official email.';
    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");
    if (!emailRegex.hasMatch(value.trim())) return 'Please enter a valid email address.';
    return null;
  }
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password.';
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
                  SizedBox(height: screenHeight * 0.04),
                  Text(
                    'Login', // PDF Page 5 ("Login")
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Text(
                    'Enter your email to sign in for this app', // PDF Page 5 subtitle
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.grey[600]),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'email@domain.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    focusNode: _emailFocusNode,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'password',
                    obscureText: true,
                    validator: _validatePassword,
                    focusNode: _passwordFocusNode,
                    onFieldSubmitted: (_) => _loginOfficial(),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  AuthButton(
                    text: 'Continue',
                    onPressed: _loginOfficial,
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
                    onPressed: _loginWithGoogleOfficial,
                    isLoading: _isLoadingGoogle,
                  ),
                  SizedBox(height: screenHeight * 0.06),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 10.0),
                     child: Text.rich(
                        TextSpan(
                          text: 'By clicking continue, you agree to official ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          children: <TextSpan>[
                            TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()..onTap = () { },
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
                      Text("Not an official? ", style: TextStyle(color: Colors.grey[700])),
                      GestureDetector(
                        onTap: () {
                           Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route)=>false);
                        },
                        child: Text(
                          'Return to Portal Selection',
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