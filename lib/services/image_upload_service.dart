// lib/services/image_upload_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer; // For logging

const String cloudinaryUploadPreset = 'authapp';
const String cloudinaryCloudName = 'dfhrq3bbi'; 

class ImageUploadService {
  Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        return responseData['secure_url'] as String?;
      } else {
        developer.log('Cloudinary Error: ${response.statusCode}', name: 'ImageUploadService');
        developer.log('Cloudinary Error Body: $responseBody', name: 'ImageUploadService');
        throw Exception('Failed to upload image to Cloudinary. Status: ${response.statusCode}');
      }
    } catch (e, s) {
      developer.log('Upload Image Exception: $e', name: 'ImageUploadService', error: e, stackTrace: s);
      return null;
    }
  }
}