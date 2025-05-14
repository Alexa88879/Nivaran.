// lib/services/risk_prediction_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class RiskPredictionService {
  // IMPORTANT: Replace this with your actual API key, preferably loaded from a secure configuration.
  // Avoid hardcoding API keys in production code.
  static const _apiKey = 'AIzaSyCVOs81A4E9PTELfPjbq3Aodo42vXWc_YE'; // Replace this

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';

  static Future<String?> getRiskPredictionFromImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            // Modified prompt for brevity
            {"text": "This image shows an infrastructure issue. Concisely describe potential long-term risks or consequences in 1-2 short sentences."},
            {
              "inlineData": {
                "mimeType": "image/jpeg", // Ensure this matches your image type
                "data": base64Image,
              }
            }
          ]
        }
      ]
    });

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Adjusted path based on typical Gemini API responses for pro-vision
        return data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];
      } else {
        // print("Gemini API error: ${response.statusCode} - ${response.body}");
        return "API Error: Could not get prediction (Status: ${response.statusCode})";
      }
    } catch (e) {
      // print("Error calling Gemini API: $e");
      return "Error: Could not connect to prediction service.";
    }
  }
}