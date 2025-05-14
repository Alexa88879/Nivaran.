// lib/screens/report/report_details_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/image_upload_service.dart';
import '../../services/location_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';
import '../../models/app_user_model.dart';
import 'dart:developer' as developer;

class ReportDetailsScreen extends StatefulWidget {
  final String imagePath;
  const ReportDetailsScreen({super.key, required this.imagePath});

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  Position? _currentPosition;
  String? _currentAddress;

  String? _selectedCategory;
  // Consider moving this list to a constants file or fetching from Firestore if it changes often
  final List<String> _categories = [
    'Pothole', 'Street Light Out', 'Waste Missed',
    'Water Leakage', 'Damaged Signage', 'Fallen Tree',
    'Illegal Dumping', 'Blocked Drain', 'Public Property Vandalism', 'Other'
  ];

  final LocationService _locationService = LocationService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _fetchLocationDetails();
  }

  Future<void> _fetchLocationDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (mounted && _currentPosition != null) {
        _currentAddress = await _locationService.getAddressFromCoordinates(
            _currentPosition!.latitude, _currentPosition!.longitude);
      }
    } catch (e) {
      developer.log('Error fetching location details: ${e.toString()}', name: 'ReportDetailsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: ${e.toString().characters.take(100)}...')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  // Helper method to map category to department
  String? _getDepartmentForCategory(String? category) {
    if (category == null) return null;

    switch (category) {
      case 'Pothole':
      case 'Damaged Signage':
      case 'Fallen Tree': // Could also be Parks & Rec or specialized tree unit
        return 'Road Maintenance Dept.';
      case 'Street Light Out':
        return 'Electricity Dept.';
      case 'Waste Missed':
      case 'Illegal Dumping':
        return 'Sanitation Dept.';
      case 'Water Leakage':
      case 'Blocked Drain': // Could also be Sanitation or a dedicated drainage department
        return 'Water Supply Dept.';
      case 'Public Property Vandalism': // Could be general or specific to the property type
        return 'Public Safety / Police'; // Or a general maintenance department
      default: // For 'Other' or unmapped categories
        return 'General Grievances'; // Or a specific department that handles uncategorized issues
    }
  }

  Future<void> _submitReport() async {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final AppUser? appUser = userProfileService.currentUserProfile;

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category for the issue.')),
        );
      }
      return;
    }

    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not available. Please try again.')),
        );
      }
      return;
    }
    if (appUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated. Please log in again.')),
        );
      
      }
      return;
    }
    if (appUser.username == null || appUser.username!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username not found. Please update your profile or re-login.')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      final String? imageUrl = await _imageUploadService.uploadImage(File(widget.imagePath));
      if (imageUrl == null) {
        throw Exception('Failed to upload image.');
      }

      final String? assignedDepartment = _getDepartmentForCategory(_selectedCategory);

      final Map<String, dynamic> issueData = {
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory!,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'address': _currentAddress ?? 'Address not available',
        },
        'userId': appUser.uid,
        'username': appUser.username!,
        'status': 'Reported', // Initial status
        'isUnresolved': true,  // For easier querying of active issues
        'assignedDepartment': assignedDepartment, // Set based on category
        'upvotes': 0,
        'downvotes': 0,
        'voters': {},
        'commentsCount': 0,
        'affectedUsersCount': 1,
        'affectedUserIds': [appUser.uid],
         // 'resolutionTimestamp': null, // Not needed at creation
      };

      await _firestoreService.addIssue(issueData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported successfully!')),
        );
        // Navigate to the main app screen for citizens or official dashboard for officials
        String targetRoute = appUser.isOfficial ? '/official_dashboard' : '/app';
        Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (Route<dynamic> route) => false);
      }

    } catch (e) {
      developer.log('Failed to submit report: ${e.toString()}', name: 'ReportDetailsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: ${e.toString().characters.take(100)}...')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        leading: IconButton(
          icon: const Icon(Icons.close), // Using default back icon color from AppBarTheme
          onPressed: () => Navigator.of(context).pop(false), // Return false if report not submitted
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(semanticsLabel: "Fetching location...",))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.imagePath.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.file(File(widget.imagePath), fit: BoxFit.contain, height: 200),
                      ),
                    SizedBox(height: screenHeight * 0.03),

                    Text("Location", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), // Adjusted style
                    SizedBox(height: screenHeight * 0.008), // Adjusted spacing
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.0), // Consistent with TextField
                        border: Border.all(color: Colors.grey[350]!)
                      ),
                      child: Text(
                            _currentAddress ?? (_currentPosition != null ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}' : 'Fetching location...'),
                            style: textTheme.bodyLarge?.copyWith(fontSize: 15), // Adjusted style
                          ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    Text("Category", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), // Adjusted style
                    SizedBox(height: screenHeight * 0.008), // Adjusted spacing
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        hintText: 'Select Category',
                        // Using theme's input decoration, ensure it's defined in main.dart
                      ),
                      value: _selectedCategory,
                      isExpanded: true,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category, style: textTheme.bodyLarge?.copyWith(fontSize: 15)), // Adjusted style
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a category.' : null,
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    Text("Description", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), // Adjusted style
                    SizedBox(height: screenHeight * 0.008), // Adjusted spacing
                    CustomTextField( // Assuming CustomTextField uses theme's InputDecoration
                      controller: _descriptionController,
                      hintText: 'Type description here...',
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description.';
                        }
                        if (value.trim().length < 10) {
                          return 'Description is too short (min 10 characters).';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: screenHeight * 0.05),

                    AuthButton(
                      text: 'Submit Report', // More descriptive text
                      onPressed: _isLoadingData ? null : _submitReport,
                      isLoading: _isSubmitting,
                    ),
                    SizedBox(height: screenHeight * 0.02),
                  ],
                ),
              ),
            ),
    );
  }
}