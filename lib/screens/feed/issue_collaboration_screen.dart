// lib/screens/feed/issue_collaboration_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

import '../../models/issue_model.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';

class IssueCollaborationScreen extends StatefulWidget {
  final String issueId;
  final Issue issue;

  const IssueCollaborationScreen({
    super.key,
    required this.issueId,
    required this.issue,
  });

  @override
  State<IssueCollaborationScreen> createState() => _IssueCollaborationScreenState();
}

class _IssueCollaborationScreenState extends State<IssueCollaborationScreen> {
  final TextEditingController _additionalInfoController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  bool _isSubmitting = false;
  final List<XFile> _additionalImages = [];
  String? _selectedContributionType = 'additional_info';

  final List<Map<String, dynamic>> _contributionTypes = [
    {
      'value': 'additional_info',
      'label': 'Additional Information',
      'icon': Icons.info_outline,
      'description': 'Add more details about this issue',
    },
    {
      'value': 'affected_user',
      'label': 'I am also affected',
      'icon': Icons.person_add_outlined,
      'description': 'Register yourself as affected by this issue',
    },
    {
      'value': 'update',
      'label': 'Status Update',
      'icon': Icons.update_outlined,
      'description': 'Provide an update on the current situation',
    },
    {
      'value': 'evidence',
      'label': 'Add Evidence',
      'icon': Icons.photo_camera_outlined,
      'description': 'Add photos as evidence for this issue',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collaborate on Issue'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Issue summary card
              Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.issue.category,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.issue.description),
                      const SizedBox(height: 8),
                      Text(
                        'Reported by ${widget.issue.username}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Contribution type selection
              const Text(
                'How would you like to contribute?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _contributionTypes.map((type) {
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type['icon'] as IconData, size: 18),
                        const SizedBox(width: 4),
                        Text(type['label'] as String),
                      ],
                    ),
                    selected: _selectedContributionType == type['value'],
                    onSelected: (selected) {
                      setState(() {
                        _selectedContributionType = selected ? type['value'] as String : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              if (_selectedContributionType != null)
                Text(
                  _contributionTypes
                      .firstWhere((t) => t['value'] == _selectedContributionType)['description'] as String,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              const SizedBox(height: 16),

              // Additional information input
              if (_selectedContributionType == 'additional_info' ||
                  _selectedContributionType == 'update')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: _additionalInfoController,
                      labelText: _selectedContributionType == 'update' ? 'Update details' : 'Additional information',
                      hintText: _selectedContributionType == 'update'
                          ? 'Describe the current status of this issue...'
                          : 'Add more details about this issue...',
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter some information';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

              // Image selection for evidence
              if (_selectedContributionType == 'evidence' || _selectedContributionType == 'update')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Photos',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Add Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_additionalImages.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _additionalImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(File(_additionalImages[index].path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _additionalImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    if (_selectedContributionType == 'evidence' && _additionalImages.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Please add at least one photo as evidence'),
                      ),
                  ],
                ),

              const SizedBox(height: 24),

              // Submit button
              AuthButton(
                text: _isSubmitting ? 'Submitting...' : 'Submit Contribution',
                onPressed: _isSubmitting ? null : _submitCollaboration,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _additionalImages.add(image);
        });
      }
    } catch (e) {
      developer.log('Error picking image: $e', name: 'IssueCollaborationScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error selecting image. Please try again.')),
        );
      }
    }
  }

  Future<void> _submitCollaboration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // For additional_info or update, require text content
    if ((_selectedContributionType == 'additional_info' || _selectedContributionType == 'update') && 
        _additionalInfoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some information')),
      );
      return;
    }
    
    // For evidence, require images
    if (_selectedContributionType == 'evidence' && _additionalImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userProfile = Provider.of<UserProfileService>(context, listen: false).currentUserProfile;
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      developer.log('Submitting collaboration for issue ${widget.issueId}', name: 'IssueCollaboration');
      
      // Prepare data for submission
      Map<String, dynamic> collaborationData = {
        'issueId': widget.issueId,
        'userId': userProfile.uid,
        'username': userProfile.username ?? 'Anonymous',
        'contributionType': _selectedContributionType,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_additionalInfoController.text.isNotEmpty) {
        collaborationData['text'] = _additionalInfoController.text.trim();
      }

      // Upload images if any
      List<String> imageUrls = [];
      if (_additionalImages.isNotEmpty) {
        developer.log('Uploading ${_additionalImages.length} images', name: 'IssueCollaboration');

        for (final image in _additionalImages) {
          final fileName = '${_uuid.v4()}.jpg';
          final ref = _storage.ref().child('issue_collaborations/$fileName');
          await ref.putFile(File(image.path));
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
          developer.log('Uploaded image: $url', name: 'IssueCollaboration');
        }

        if (imageUrls.isNotEmpty) {
          collaborationData['imageUrls'] = imageUrls;
        }
      }

      // Save to Firestore
      DocumentReference docRef = await _firestore.collection('issue_collaborations').add(collaborationData);
      developer.log('Collaboration document created with ID: ${docRef.id}', name: 'IssueCollaboration');

      // If this is a status update, add to status history
      if (_selectedContributionType == 'update') {
        DocumentReference statusRef = await _firestore
            .collection('issues')
            .doc(widget.issueId)
            .collection('status_updates')
            .add({
          'status': 'Updated by citizen',
          'updatedBy': userProfile.username ?? 'Anonymous',
          'timestamp': FieldValue.serverTimestamp(),
          'comments': _additionalInfoController.text.trim(),
        });
        developer.log('Status update added with ID: ${statusRef.id}', name: 'IssueCollaboration');
      }

      // Update issue if marking as affected
      if (_selectedContributionType == 'affected_user') {
        await _firestore.collection('issues').doc(widget.issueId).update({
          'peopleAffected': FieldValue.increment(1),
          'affectedUserIds': FieldValue.arrayUnion([userProfile.uid]),
        });
        developer.log('Incremented peopleAffected count', name: 'IssueCollaboration');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribution submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      developer.log('Error submitting contribution: $e', name: 'IssueCollaboration', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting contribution: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }
}
