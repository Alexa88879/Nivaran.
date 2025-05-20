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
  final TextEditingController _tagsController = TextEditingController(); // For tags input
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  Position? _currentPosition;
  String? _currentAddress;

  String? _selectedCategory;
  final List<String> _categories = [
    'Pothole', 'Street Light Out', 'Waste Missed',
    'Water Leakage', 'Damaged Signage', 'Fallen Tree',
    'Illegal Dumping', 'Blocked Drain', 'Public Property Vandalism', 'Other'
  ];

  String? _selectedUrgency; // For urgency dropdown
  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];


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

  String? _getDepartmentForCategory(String? category) {
    if (category == null) return null;
    switch (category) {
      case 'Pothole':
      case 'Damaged Signage':
      case 'Fallen Tree':
        return 'Road Maintenance Dept.';
      case 'Street Light Out':
        return 'Electricity Dept.';
      case 'Waste Missed':
      case 'Illegal Dumping':
        return 'Sanitation Dept.';
      case 'Water Leakage':
      case 'Blocked Drain':
        return 'Water Supply Dept.';
      case 'Public Property Vandalism':
        return 'Public Safety / Police';
      default:
        return 'General Grievances';
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
    // Urgency is optional, so no specific check here unless you make it mandatory
    // if (_selectedUrgency == null) {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('Please select an urgency level.')),
    //     );
    //   }
    //   return;
    // }


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
      
      // Process tags: split by comma, trim whitespace, remove empty tags
      final List<String> tagsList = _tagsController.text.split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final Map<String, dynamic> issueData = {
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory!,
        'urgency': _selectedUrgency, // Can be null if not selected
        'tags': tagsList.isNotEmpty ? tagsList : null, // Store as list, or null if empty
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'address': _currentAddress ?? 'Address not available',
        },
        'userId': appUser.uid,
        'username': appUser.username!,
        'status': 'Reported',
        'isUnresolved': true,
        'assignedDepartment': assignedDepartment,
        'upvotes': 0,
        'downvotes': 0,
        'voters': {},
        'commentsCount': 0,
        'affectedUsersCount': 1,
        'affectedUserIds': [appUser.uid],
      };

      await _firestoreService.addIssue(issueData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported successfully!')),
        );
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
    _tagsController.dispose(); // Dispose new controller
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
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
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

                    Text("Location", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey[350]!)
                      ),
                      child: Text(
                            _currentAddress ?? (_currentPosition != null ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}' : 'Fetching location...'),
                            style: textTheme.bodyLarge?.copyWith(fontSize: 15),
                          ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    Text("Category*", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: 'Select Category',
                      ),
                      value: _selectedCategory,
                      isExpanded: true,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category, style: textTheme.bodyLarge?.copyWith(fontSize: 15)),
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
                    
                    // --- Urgency Level Dropdown ---
                    Text("Urgency Level (Optional)", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: 'Select Urgency',
                      ),
                      value: _selectedUrgency,
                      isExpanded: true,
                      items: _urgencyLevels.map((String level) {
                        return DropdownMenuItem<String>(
                          value: level,
                          child: Text(level, style: textTheme.bodyLarge?.copyWith(fontSize: 15)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedUrgency = newValue;
                        });
                      },
                      // No validator, as it's optional
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    Text("Description*", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    CustomTextField(
                      controller: _descriptionController,
                      hintText: 'Type description here...',
                      maxLines: 4, // Reduced slightly
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
                    SizedBox(height: screenHeight * 0.03),

                    // --- Tags Input ---
                    Text("Tags (Optional, comma-separated)", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    CustomTextField(
                      controller: _tagsController,
                      hintText: 'e.g., broken, urgent, road_hazard',
                      maxLines: 1,
                      keyboardType: TextInputType.text,
                      // No validator, as it's optional
                    ),
                    SizedBox(height: screenHeight * 0.05),


                    AuthButton(
                      text: 'Submit Report',
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
