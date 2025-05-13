// lib/screens/official/official_details_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../common/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';
import '../../services/user_profile_service.dart';
import 'dart:developer' as developer;

class OfficialDetailsEntryScreen extends StatefulWidget {
  const OfficialDetailsEntryScreen({super.key});

  @override
  State<OfficialDetailsEntryScreen> createState() => _OfficialDetailsEntryScreenState();
}

class _OfficialDetailsEntryScreenState extends State<OfficialDetailsEntryScreen> {
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _governmentIdController = TextEditingController();
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedDepartment;

  // This list should ideally be fetched from Firestore or a remote config.
  final List<String> _departments = [
    "Road Maintenance Dept.", "Electricity Dept.", "Sanitation Dept.",
    "Water Supply Dept.", "Parks & Recreation", "Public Safety / Police",
    "Traffic Management", "Urban Planning", "Health Services",
    "Education Department", "General Grievances", "Other"
  ];

  @override
  void dispose() {
    _designationController.dispose();
    _areaController.dispose();
    _governmentIdController.dispose();
    super.dispose();
  }

  Future<void> _submitOfficialDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication error. Please sign up or log in again.")),
        );
        // Navigate back to role selection or official auth options
        Navigator.of(context).pushNamedAndRemoveUntil('/auth_options', ModalRoute.withName('/role_selection'), arguments: 'official');
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      Map<String, dynamic> officialDetailsToUpdate = {
        'designation': _designationController.text.trim(),
        'department': _selectedDepartment,
        'area': _areaController.text.trim(),
        'governmentId': _governmentIdController.text.trim(),
       
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(officialDetailsToUpdate); // Use update, as base doc was created

      if (mounted) {
        // Refresh UserProfileService with the newly added Firestore fields
        await Provider.of<UserProfileService>(context, listen: false).fetchAndSetCurrentUserProfile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: Duration(seconds: 3), content: Text("Official details submitted. Your account registration is pending admin review and activation.")),
        );
        // After submitting details, navigate them out of the auth flow.
        // They can't use official features until an admin approves and sets their role via custom claims.
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
        }
      }

    } catch (e) {
      developer.log("Error submitting official details: $e", name: "OfficialDetailsEntry");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit details: ${e.toString()}")),
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // No back button typically in a multi-step flow screen like this,
        // as progress should be forward or cancellation handled differently.
        // If back navigation is desired here, add:
        // leading: IconButton(icon: Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
        automaticallyImplyLeading: false, 
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
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Details', // PDF Page 7 Title
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(fontSize: 26),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Enter your official details', // PDF Page 7 Subtitle
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 15, color: Colors.grey[600]),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  CustomTextField(
                    controller: _designationController,
                    hintText: 'designation',
                    textCapitalization: TextCapitalization.words,
                    validator: (val) => _validateNotEmpty(val, "Designation"),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: 'department', 
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[350]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[350]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
                    ),
                    value: _selectedDepartment,
                    isExpanded: true,
                    hint: Text('department', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                    items: _departments.map((String department) {
                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(department, style: const TextStyle(fontSize: 15)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDepartment = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Department is required.' : null,
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _areaController,
                    hintText: 'area', 
                    textCapitalization: TextCapitalization.words,
                    validator: (val) => _validateNotEmpty(val, "Area / Zone of Operation"),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  CustomTextField(
                    controller: _governmentIdController,
                    hintText: 'government id',
                    validator: (val) => _validateNotEmpty(val, "Government ID"),
                    onFieldSubmitted: (_) => _submitOfficialDetails(),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  AuthButton(
                    text: 'Submit', 
                    onPressed: _submitOfficialDetails,
                    isLoading: _isLoading,
                  ),
                   SizedBox(height: screenHeight * 0.04),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}