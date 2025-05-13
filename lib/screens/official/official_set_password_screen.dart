// lib/screens/official/official_set_password_screen.dart
import 'package:flutter/material.dart';
import '../../common/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';

import 'dart:developer' as developer;

class OfficialSetPasswordScreen extends StatefulWidget {

  const OfficialSetPasswordScreen({super.key /*, this.actionCode */});

  @override
  State<OfficialSetPasswordScreen> createState() => _OfficialSetPasswordScreenState();
}

class _OfficialSetPasswordScreenState extends State<OfficialSetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitNewPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);


    await Future.delayed(const Duration(seconds: 1)); 
    developer.log("New password submitted (actual logic pending): ${_passwordController.text}", name:"OfficialSetPassword");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password update functionality placeholder.")),
      );
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    }

    if (mounted) setState(() => _isLoading = false);
  }

   String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a new password.';
    if (value.length < 6) return 'Password must be at least 6 characters long.';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your new password.';
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
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: screenHeight * 0.05),
                  Text(
                    'Password', // PDF Page 8 Title
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Set your password', // PDF Page 8 Subtitle
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.grey[600]),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'new password', // Matches PDF placeholder
                    obscureText: true,
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: 'confirm new password', // Matches PDF placeholder
                    obscureText: true,
                    validator: _validateConfirmPassword,
                    onFieldSubmitted: (_) => _submitNewPassword(),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  AuthButton(
                    text: 'Submit', // Matches PDF
                    onPressed: _submitNewPassword,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}