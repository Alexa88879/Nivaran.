// lib/services/image_upload_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart'; // To get current user for path
import 'package:uuid/uuid.dart'; // For generating unique filenames
import 'dart:developer' as developer;

class ImageUploadService {
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  Future<String?> uploadImage(File imageFile) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      developer.log('User not authenticated, cannot upload image.', name: 'ImageUploadService');
      throw Exception('User not authenticated. Cannot upload image.');
    }

    try {
      // Generate a unique filename to avoid overwrites and ensure privacy if needed
      final String fileExtension = imageFile.path.split('.').last;
      final String fileName = '${_uuid.v4()}.$fileExtension';
      
      // Define the path in Firebase Storage.
      // It's good practice to organize images, e.g., by user or by feature.
      // For issues, a path like 'issues_images/userId/fileName' or 'issues_images/issueId/fileName' could work.
      // For simplicity here, we'll use 'issues_images/fileName'.
      // Consider adding userId to the path for better organization: 'issues_images/${currentUser.uid}/$fileName'
      final String filePath = 'issues_images/$fileName';
      
      firebase_storage.Reference ref = _storage.ref().child(filePath);

      developer.log('Uploading image to Firebase Storage at path: $filePath', name: 'ImageUploadService');

      // Upload the file
      firebase_storage.UploadTask uploadTask = ref.putFile(imageFile);

      // Wait for the upload to complete
      firebase_storage.TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      developer.log('Image uploaded successfully. Download URL: $downloadUrl', name: 'ImageUploadService');
      return downloadUrl;

    } on firebase_storage.FirebaseException catch (e) {
      developer.log('Firebase Storage Error: ${e.code} - ${e.message}', name: 'ImageUploadService', error: e);
      // Handle specific Firebase Storage errors
      // e.g., e.code == 'object-not-found', 'unauthorized', 'canceled', etc.
      throw Exception('Failed to upload image to Firebase Storage. Error: ${e.message}');
    } catch (e, s) {
      developer.log('Upload Image Exception: $e', name: 'ImageUploadService', error: e, stackTrace: s);
      // Return null or rethrow a custom exception
      return null; 
    }
  }
}
