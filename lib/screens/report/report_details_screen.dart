// lib/screens/report/report_details_screen.dart
import 'dart:io';
import 'dart:convert'; // For base64Encode and jsonEncode
import 'dart:async'; 

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/image_upload_service.dart';
import '../../services/location_service.dart';
import '../../services/firestore_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/auth_button.dart';
import '../../models/app_user_model.dart';
import '../../models/category_model.dart';
import '../../models/issue_model.dart'; // For LocationModel
import '../../secrets.dart'; 
import 'dart:developer' as developer;

// Helper class for language options
class SpeechLanguage {
  final String code;
  final String name;
  const SpeechLanguage(this.code, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeechLanguage &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class ReportDetailsScreen extends StatefulWidget {
  final String imagePath;
  const ReportDetailsScreen({super.key, required this.imagePath});

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoadingInitialData = true;
  bool _isSubmitting = false;
  Position? _currentPosition;
  String? _currentAddress;

  List<CategoryModel> _fetchedCategories = [];
  CategoryModel? _selectedCategoryModel;

  final LocationService _locationService = LocationService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final FirestoreService _firestoreService = FirestoreService();

  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  String? _recordedAudioPath;
  bool _audioRecorderInitialized = false;
  final String _tempAudioFileName = 'temp_audio.amr'; 
  final int _targetSampleRate = 16000; 

  bool _isProcessingSTT = false; 
  bool _isTranslatingText = false; 
  bool _isSuggestingCategory = false; 
  String? _originalTranscribedText; 
  late SpeechLanguage _selectedSpokenLanguage;
  
  String? _detectedUrgency;
  bool _isDetectingUrgency = false;


  static const List<SpeechLanguage> _supportedSpokenLanguages = [
    SpeechLanguage('en-IN', 'English (India)'),
    SpeechLanguage('hi-IN', 'हिन्दी (Hindi)'),
    SpeechLanguage('bn-IN', 'বাংলা (Bengali)'),
    SpeechLanguage('ta-IN', 'தமிழ் (Tamil)'),
    SpeechLanguage('te-IN', 'తెలుగు (Telugu)'),
    SpeechLanguage('mr-IN', 'मराठी (Marathi)'),
    SpeechLanguage('gu-IN', 'ગુજરાતી (Gujarati)'),
    SpeechLanguage('kn-IN', 'ಕನ್ನಡ (Kannada)'),
    SpeechLanguage('ml-IN', 'മലയാളം (Malayalam)'),
    SpeechLanguage('pa-Guru-IN', 'ਪੰਜਾਬੀ (Punjabi)'),
    SpeechLanguage('ur-IN', 'اردو (Urdu - India)'),
    SpeechLanguage('as-IN', 'অসমীয়া (Assamese)'),
    SpeechLanguage('or-IN', 'ଓଡ଼ିଆ (Odia)'),
    SpeechLanguage('mai-IN', 'मैथिली (Maithili)'),
    SpeechLanguage('doi-IN', 'डोगरी (Dogri)'),
    SpeechLanguage('ne-IN', 'नेपाली (Nepali - India)'),
  ];


  @override
  void initState() {
    super.initState();
    _selectedSpokenLanguage = _supportedSpokenLanguages.firstWhere(
        (lang) => lang.code == 'hi-IN', 
        orElse: () => _supportedSpokenLanguages.first
    );
    _audioRecorder = FlutterSoundRecorder(); 
    _initializeAudioRecorder();
    _fetchInitialData();
  }

  Future<void> _initializeAudioRecorder() async {
    try {
      var micStatus = await Permission.microphone.request();
      if (micStatus.isGranted) {
        await _audioRecorder!.openRecorder();
        _audioRecorderInitialized = true;
        developer.log("Audio recorder initialized.", name: "ReportDetailsScreen");
      } else {
        _audioRecorderInitialized = false;
        developer.log("Microphone permission not granted.", name: "ReportDetailsScreen");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required.')),
          );
        }
      }
    } catch (e) {
      _audioRecorderInitialized = false;
      developer.log("Error initializing audio recorder: $e", name: "ReportDetailsScreen");
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed to initialize audio recorder: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoadingInitialData = true);
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (mounted && _currentPosition != null) {
        _currentAddress = await _locationService.getAddressFromCoordinates(
            _currentPosition!.latitude, _currentPosition!.longitude);
      }
      _fetchedCategories = await _firestoreService.fetchIssueCategories();
      if (_fetchedCategories.isEmpty && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load issue categories.')),
        );
      }
    } catch (e) {
      developer.log('Error fetching initial data: ${e.toString()}', name: 'ReportDetailsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: ${e.toString().characters.take(100)}...')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingInitialData = false);
    }
  }

  Future<void> _startRecording() async {
    if (!_audioRecorderInitialized || _audioRecorder == null || _isRecording) return;
    try {
      Directory tempDir = await getTemporaryDirectory();
      _recordedAudioPath = '${tempDir.path}/$_tempAudioFileName'; 
      await _audioRecorder!.startRecorder(
        toFile: _recordedAudioPath,
        codec: Codec.amrWB, 
        sampleRate: _targetSampleRate, 
        numChannels: 1, 
      );
      if (mounted) {
        setState(() {
          _isRecording = true;
          _descriptionController.text = "Listening in ${_selectedSpokenLanguage.name}...";
          _originalTranscribedText = null; 
          _detectedUrgency = null; 
        });
      }
      developer.log("Started recording to: $_recordedAudioPath (AMR_WB) at $_targetSampleRate Hz, 1 channel, Language: ${_selectedSpokenLanguage.code}", name: "ReportDetailsScreen");
    } catch (e) {
      developer.log("Error starting recording: $e", name: "ReportDetailsScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to start recording: ${e.toString()}")));
         setState(() {
          _isRecording = false;
          _descriptionController.clear();
        });
      }
    }
  }

  Future<void> _stopRecordingAndProcessAudio() async { 
    if (!_audioRecorderInitialized || _audioRecorder == null || !_isRecording) return;
    
    String? audioFilePath;
    try {
      audioFilePath = await _audioRecorder!.stopRecorder();
      developer.log("Stopped recording. Audio at: $audioFilePath", name: "ReportDetailsScreen");

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessingSTT = true; 
          _descriptionController.text = "Processing audio...";
          _recordedAudioPath = audioFilePath; 
        });
      } else {
        return; 
      }

      if (_recordedAudioPath != null && _recordedAudioPath!.isNotEmpty) {
        File audioFile = File(_recordedAudioPath!);
        await Future.delayed(const Duration(milliseconds: 300)); 

        if (await audioFile.exists()) {
          int fileLength = await audioFile.length();
          developer.log("Audio file exists. Path: $_recordedAudioPath. Size: $fileLength bytes", name: "ReportDetailsScreen");

          if (fileLength < 1024) { 
            developer.log("Recorded audio file is very small ($fileLength bytes).", name: "ReportDetailsScreen");
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recorded audio is too short. Please speak longer.")));
            if (mounted) {
              setState(() {
                 _isProcessingSTT = false;
                 _descriptionController.clear();
              });
            }
            return;
          }

          List<int> audioBytes = await audioFile.readAsBytes();
          String base64Audio = base64Encode(audioBytes);
          
          Map<String, String?>? sttResult = await _googleCloudSpeechToText(base64Audio, _selectedSpokenLanguage.code);

          if (mounted) setState(() => _isProcessingSTT = false);

          String? transcribedText = sttResult?['transcript'];

          if (transcribedText != null && transcribedText.isNotEmpty) {
            if (mounted) {
              setState(() {
                _originalTranscribedText = transcribedText; 
              });
            }
            String finalTextForDescription = transcribedText;
            
            bool processForEnglish = true; 

            if (processForEnglish) {
              if (mounted) setState(() => _isTranslatingText = true);
              String? processedText = await _translateOrRefineToIndianEnglishGemini(transcribedText, sourceLanguage: _selectedSpokenLanguage.code);
              if (mounted) setState(() => _isTranslatingText = false);
              if (processedText != null && processedText.isNotEmpty) {
                finalTextForDescription = processedText;
              } else {
                 developer.log("Translation/refinement failed, using original STT output: $transcribedText", name: "ReportDetailsScreen");
              }
            }
            
            if (mounted) {
              _descriptionController.text = finalTextForDescription;
              // Check if original should be hidden (if it's English and same as final)
              if (_selectedSpokenLanguage.code.toLowerCase().startsWith('en') || 
                  finalTextForDescription.trim().toLowerCase() == _originalTranscribedText?.trim().toLowerCase()) {
                  setState(() { _originalTranscribedText = null; }); 
              }
              
              // Proceed with AI suggestions
              await _suggestCategoryGemini(finalTextForDescription);
              if (mounted && widget.imagePath.isNotEmpty && _currentPosition != null) {
                 List<int> imageBytesForUrgency = await File(widget.imagePath).readAsBytes();
                 String imageBase64ForUrgency = base64Encode(imageBytesForUrgency);
                 LocationModel locModel = LocationModel(latitude: _currentPosition!.latitude, longitude: _currentPosition!.longitude, address: _currentAddress ?? "Unknown address");
                 await _detectUrgencyGemini(finalTextForDescription, imageBase64ForUrgency, locModel);
              } else {
                developer.log("Skipping urgency detection: image, location, or description missing.", name: "ReportDetailsScreen");
              }
            }
          } else {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not transcribe audio. Please ensure you spoke clearly.")));
                _descriptionController.clear(); 
                setState(() => _originalTranscribedText = null);
             }
          }
        } else {
          developer.log("Recorded audio file does not exist: $_recordedAudioPath", name: "ReportDetailsScreen");
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Recorded audio file not found.")));
             _descriptionController.clear();
           }
        }
      } else {
         developer.log("Audio path is null or empty after stopping recorder.", name: "ReportDetailsScreen");
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Could not get recorded audio path.")));
            _descriptionController.clear();
         }
      }
    } catch (e, s) {
      developer.log("Error stopping recording or processing audio: $e", name: "ReportDetailsScreen", stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing audio: ${e.toString()}")));
        setState(() { 
          _isRecording = false;
          _isProcessingSTT = false;
          _isTranslatingText = false;
          _isSuggestingCategory = false;
          _isDetectingUrgency = false;
          _descriptionController.clear();
        });
      }
    } 
  }

  Future<Map<String, String?>?> _googleCloudSpeechToText(String base64Audio, String languageCodeForSTT) async {
    final String apiKey = googleSpeechToTextApiKey; 
    const String url = 'https://speech.googleapis.com/v1/speech:recognize';
    
    final Map<String, dynamic> requestBody = {
      "config": {
        "encoding": "AMR_WB", 
        "sampleRateHertz": _targetSampleRate, 
        "audioChannelCount": 1, 
        "languageCode": languageCodeForSTT, 
        "enableAutomaticPunctuation": true,
        "enableWordConfidence": true, 
        "model": "default" 
      },
      "audio": {
        "content": base64Audio,
      }
    };

    developer.log("Sending to Google STT with config: ${jsonEncode(requestBody['config'])}", name: "ReportDetailsScreen");

    try {
      final response = await http.post(
        Uri.parse('$url?key=$apiKey'), 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (!mounted) return null;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        developer.log("Google STT Full Response: ${response.body}", name: "ReportDetailsScreen"); 

        if (responseData['results'] != null && responseData['results'].isNotEmpty) {
          String fullTranscript = "";
          String? sttReturnedLanguageCode = responseData['results'][0]['languageCode'] as String?;

          for (int i = 0; i < responseData['results'].length; i++) {
            var result = responseData['results'][i];
            if (result['alternatives'] != null && result['alternatives'].isNotEmpty) {
              fullTranscript += (result['alternatives'][0]['transcript'] as String? ?? "") + " ";
            }
          }
          fullTranscript = fullTranscript.trim();
          
          if (sttReturnedLanguageCode != null) {
            developer.log("Google STT (in-result) detected language: $sttReturnedLanguageCode (User selected: $languageCodeForSTT)", name: "ReportDetailsScreen");
          } else {
             developer.log("Google STT did not explicitly return a language code in the result object. User selected: $languageCodeForSTT", name: "ReportDetailsScreen");
          }
          
          if (fullTranscript.isNotEmpty) {
            developer.log("Google STT Transcription: $fullTranscript", name: "ReportDetailsScreen");
            return {'transcript': fullTranscript, 'detectedLanguageCode': sttReturnedLanguageCode ?? languageCodeForSTT};
          } else {
            developer.log("Google STT: 'results' array was present but alternatives or transcript was empty.", name: "ReportDetailsScreen");
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Speech recognized, but no text could be transcribed. Try again.")));
            return null;
          }
        } else {
          developer.log("Google STT: No 'results' array in response or it's empty.", name: "ReportDetailsScreen");
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No speech detected or recognized. Please speak clearly.")));
          return null;
        }
      } else {
        developer.log("Google STT API Error: ${response.statusCode} - ${response.body}", name: "ReportDetailsScreen");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech-to-Text Error: ${response.statusCode}. Details: ${response.reasonPhrase}')),
          );
        }
        return null;
      }
    } catch (e) {
      developer.log("Exception during Google STT API call: $e", name: "ReportDetailsScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to Speech-to-Text service: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  Future<String?> _translateOrRefineToIndianEnglishGemini(String textToProcess, {String? sourceLanguage}) async {
    if (textToProcess.isEmpty) return null;
    
    String instruction;
    String exampleInput = "हमारे गांव में नाला खराब हो गया है। कृपया उसे ठीक करवाएं।"; 
    String exampleOutput = "The drain in our village is damaged; please arrange for its repair."; 

    if (sourceLanguage != null && sourceLanguage.toLowerCase().startsWith('en')) {
      instruction = "Refine the following English text, which may contain Hinglish or colloquial Indian English phrases, into a single, clear, standard Indian English sentence. Output only the refined sentence.";
    } else if (sourceLanguage != null) { 
      instruction = "Translate the following text from its original Indian language (spoken as $sourceLanguage) into a single, clear, standard Indian English sentence. Output only the translated sentence.";
    } else { 
      instruction = "The following text might be in an Indian language or Hinglish. Convert it into a single, clear, standard Indian English sentence. Output only the converted sentence.";
    }
    
    String prompt = "$instruction For example, if the input implies a problem like '$exampleInput', the output should be like '$exampleOutput'.\n\nInput Text: \"$textToProcess\"\n\nOutput (only the single processed sentence):";

    final payload = {
      "contents": [{"parts": [{"text": prompt}]}],
      "generationConfig": {
        "temperature": 0.2, 
        "maxOutputTokens": textToProcess.length * 4 + 150, 
        "stopSequences": ["\n\n", "Input Text:", "Output:", "Desired Output Format:"] 
      }
    };

    developer.log("Sending to Gemini for translation/refinement. Full Prompt: $prompt", name: "ReportDetailsScreen");

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (!mounted) return null;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        developer.log("Gemini Translation/Refinement Full Response: ${response.body}", name: "ReportDetailsScreen");
        if (result['candidates'] != null && result['candidates'].isNotEmpty &&
            result['candidates'][0]['content'] != null &&
            result['candidates'][0]['content']['parts'] != null &&
            result['candidates'][0]['content']['parts'].isNotEmpty) {
          String processedText = result['candidates'][0]['content']['parts'][0]['text'].trim();
          
          List<String> prefixesToRemove = [
            "Output (single Indian English sentence):", "Output:", "The refined sentence is:",
            "Here is the refined sentence:", "Translation:", "Standard Indian English:",
            "Desired Output Format (single, standard Indian English sentence):" 
          ];
          for (String prefix in prefixesToRemove) {
            if (processedText.toLowerCase().startsWith(prefix.toLowerCase())) {
              processedText = processedText.substring(prefix.length).trim();
            }
          }
          processedText = processedText.replaceAll("\"", "").trim(); 

          developer.log("Gemini Translation/Refinement to Indian English (cleaned): $processedText", name: "ReportDetailsScreen");
          return processedText.isNotEmpty ? processedText : null; 
        } else {
          developer.log("Gemini Translation/Refinement: Unexpected response structure.", name: "ReportDetailsScreen");
        }
      } else {
        developer.log("Gemini Translation/Refinement API Error: ${response.statusCode} - ${response.body}", name: "ReportDetailsScreen");
      }
    } catch (e) {
      developer.log("Error calling Gemini for translation/refinement: $e", name: "ReportDetailsScreen");
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Text processing to Indian English failed. Using original text.")));
    }
    return null; 
  }

  Future<void> _detectUrgencyGemini(String description, String imageBase64, LocationModel location) async {
    if (description.isEmpty) return;
    if (mounted) setState(() => _isDetectingUrgency = true);

    String locationContext = "Location: ${location.address}. Coordinates: (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}).";
    String prompt = 
        "Analyze the following civic issue report to determine its urgency. Consider the description, the visual information from the image, and the location context. Respond with only one of these urgency levels: 'Low', 'Medium', or 'High'.\n\n"
        "Description: \"$description\"\n"
        "Location Context: \"$locationContext\"\n\n"
        "Image is provided. Based on all this, the urgency level is:";

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inlineData": {
                "mimeType": "image/jpeg", 
                "data": imageBase64
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.3,
        "maxOutputTokens": 10, 
        "stopSequences": ["\n"]
      }
    };
    developer.log("Sending to Gemini for Urgency Detection. Prompt (text part): $prompt", name: "ReportDetailsScreen");

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        developer.log("Gemini Urgency Detection Full Response: ${response.body}", name: "ReportDetailsScreen");
        if (result['candidates'] != null &&
            result['candidates'].isNotEmpty &&
            result['candidates'][0]['content'] != null &&
            result['candidates'][0]['content']['parts'] != null &&
            result['candidates'][0]['content']['parts'].isNotEmpty) {
          String detectedLevel = result['candidates'][0]['content']['parts'][0]['text'].trim();
          
          if (['Low', 'Medium', 'High'].any((level) => level.toLowerCase() == detectedLevel.toLowerCase())) {
            setState(() {
              _detectedUrgency = detectedLevel;
            });
            developer.log("AI Detected Urgency: $_detectedUrgency", name: "ReportDetailsScreen");
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Detected Urgency: $_detectedUrgency')));
          } else {
            developer.log("Gemini returned unexpected urgency level: $detectedLevel", name: "ReportDetailsScreen");
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI could not determine urgency reliably.')));
             setState(() => _detectedUrgency = "Medium"); 
          }
        } else {
          developer.log("Gemini Urgency Detection: Unexpected response structure.", name: "ReportDetailsScreen");
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI urgency detection format error.')));
           setState(() => _detectedUrgency = "Medium"); 
        }
      } else {
        developer.log("Gemini Urgency Detection API Error: ${response.statusCode} - ${response.body}", name: "ReportDetailsScreen");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Urgency Detection Error: ${response.statusCode}')));
        setState(() => _detectedUrgency = "Medium"); 
      }
    } catch (e) {
      developer.log("Error calling Gemini for urgency detection: $e", name: "ReportDetailsScreen");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error in AI urgency detection: ${e.toString()}')));
      setState(() => _detectedUrgency = "Medium"); 
    } finally {
      if (mounted) setState(() => _isDetectingUrgency = false);
    }
  }


  Future<void> _suggestCategoryGemini(String descriptionText) async {
    if (descriptionText.isEmpty) return;
    if (!mounted) return;
    setState(() => _isSuggestingCategory = true);

    final categoryNames = _fetchedCategories.map((c) => c.name).toList();
    if (categoryNames.isEmpty) {
        developer.log("No categories fetched, cannot suggest category.", name: "ReportDetailsScreen");
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Categories not loaded, cannot auto-suggest.")),
            );
            setState(() => _isSuggestingCategory = false);
        }
        return;
    }
    
    String prompt = "Given the issue description: '$descriptionText', and the available categories: [${categoryNames.join(', ')}]. Which single category from the list is the most appropriate for this issue? Respond with only the category name from the list. If none from the list are a good fit, respond with 'Other'.";
    
    final payload = {
      "contents": [{"parts": [{"text": prompt}]}],
      "generationConfig": {"temperature": 0.4, "maxOutputTokens": 50}
    };

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['candidates'] != null && result['candidates'].isNotEmpty &&
            result['candidates'][0]['content'] != null &&
            result['candidates'][0]['content']['parts'] != null &&
            result['candidates'][0]['content']['parts'].isNotEmpty) {
          String suggestedCategoryName = result['candidates'][0]['content']['parts'][0]['text'].trim();
           developer.log("Gemini suggested category: $suggestedCategoryName", name: "ReportDetailsScreen");
          CategoryModel? matchedCategory = _fetchedCategories.firstWhere(
              (cat) => cat.name.toLowerCase() == suggestedCategoryName.toLowerCase(),
              orElse: () => null_category_model 
          );
           if (matchedCategory != null_category_model) {
            setState(() => _selectedCategoryModel = matchedCategory);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI suggested category: ${matchedCategory.name}')));
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI suggested "$suggestedCategoryName", not in list. Please select manually.')));
          }
        } else {
           developer.log("Gemini Category Suggestion: Unexpected response structure: ${response.body}", name: "ReportDetailsScreen");
        }
      } else {
        developer.log("Gemini Category Suggestion API Error: ${response.statusCode} - ${response.body}", name: "ReportDetailsScreen");
      }
    } catch (e) {
      developer.log("Error calling Gemini for category suggestion: $e", name: "ReportDetailsScreen");
    } finally {
      if (mounted) setState(() => _isSuggestingCategory = false);
    }
  }
  
  static final CategoryModel null_category_model = CategoryModel(id: '', name: '', defaultDepartment: '');

  Future<void> _submitReport() async {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final AppUser? appUser = userProfileService.currentUserProfile;

    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryModel == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category.')));
      return;
    }
     if (_detectedUrgency == null) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Urgency level has not been determined yet.')));
      return;
    }
    if (_currentPosition == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available.')));
      return;
    }
    if (appUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not authenticated.')));
      return;
    }
     if (appUser.username == null || appUser.username!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username not found.')));
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      final String? imageUrl = await _imageUploadService.uploadImage(File(widget.imagePath));
      if (imageUrl == null) throw Exception('Failed to upload image.');
      
      final String assignedDepartment = _selectedCategoryModel!.defaultDepartment; 
      final List<String> tagsList = _tagsController.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();

      final Map<String, dynamic> issueData = {
        'description': _descriptionController.text.trim(), 
        'category': _selectedCategoryModel!.name,
        'urgency': _detectedUrgency, 
        'tags': tagsList.isNotEmpty ? tagsList : null,
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
        'originalSpokenText': (_originalTranscribedText != null && _originalTranscribedText!.trim().toLowerCase() != _descriptionController.text.trim().toLowerCase()) ? _originalTranscribedText : null,
        'userInputLanguage': _selectedSpokenLanguage.code, 
      };

      await _firestoreService.addIssue(issueData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue reported successfully!')));
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
    _tagsController.dispose();
    _audioRecorder?.closeRecorder().catchError((e) {
      developer.log("Error closing recorder on dispose: $e", name: "ReportDetailsScreen");
    });
    _audioRecorder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;
    
    bool isAnyProcessing = _isProcessingSTT || _isTranslatingText || _isSuggestingCategory || _isDetectingUrgency;
    
    // Updated logic for showOriginalText
    bool showOriginalText = !_selectedSpokenLanguage.code.toLowerCase().startsWith('en') && // Only show if non-English was selected for speaking
                           _originalTranscribedText != null && 
                           _originalTranscribedText!.isNotEmpty &&
                           _originalTranscribedText!.trim().toLowerCase() != _descriptionController.text.trim().toLowerCase();


    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator(semanticsLabel: "Loading details...",))
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
                    SizedBox(height: screenHeight * 0.02),
                    
                    Text("Spoken Language for Recording", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    DropdownButtonFormField<SpeechLanguage>(
                      decoration: InputDecoration(
                        hintText: 'Select Language',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.grey[350]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.grey[350]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                      ),
                      value: _selectedSpokenLanguage,
                      isExpanded: true,
                      items: _supportedSpokenLanguages.map((SpeechLanguage language) {
                        return DropdownMenuItem<SpeechLanguage>(
                          value: language,
                          child: Text(language.name, style: textTheme.bodyLarge?.copyWith(fontSize: 15)),
                        );
                      }).toList(),
                      onChanged: (SpeechLanguage? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedSpokenLanguage = newValue;
                          });
                           developer.log("User selected spoken language: ${newValue.name} (${newValue.code})", name: "ReportDetailsScreen");
                        }
                      },
                    ),
                    SizedBox(height: screenHeight * 0.02),


                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Description*", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              SizedBox(height: screenHeight * 0.008),
                              CustomTextField(
                                controller: _descriptionController,
                                hintText: _isRecording ? 'Listening in ${_selectedSpokenLanguage.name}...' : (isAnyProcessing ? 'Processing...' : 'Type or speak description...'),
                                maxLines: 4,
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
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Padding(
                          padding: const EdgeInsets.only(top: 30.0), 
                          child: IconButton(
                            icon: Icon(
                              _isRecording ? Icons.stop_circle_outlined : Icons.mic_rounded,
                              color: _isRecording ? Colors.red.shade700 : Theme.of(context).primaryColor,
                              size: 30,
                            ),
                            tooltip: _isRecording ? "Stop Recording" : "Record Description in ${_selectedSpokenLanguage.name}",
                            onPressed: (_audioRecorderInitialized && !isAnyProcessing)
                                ? (_isRecording ? _stopRecordingAndProcessAudio : _startRecording)
                                : null, 
                          ),
                        ),
                      ],
                    ),
                    if (isAnyProcessing) 
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 8),
                            Text(
                              _isProcessingSTT ? "Transcribing..." : 
                              _isDetectingUrgency ? "Detecting urgency..." : // Added this
                              _isTranslatingText ? "Processing to Indian English..." : 
                              _isSuggestingCategory ? "Suggesting category..." : "Processing...", 
                              style: const TextStyle(fontStyle: FontStyle.italic)
                            ),
                          ],
                        ),
                      ),
                    Visibility(
                      visible: showOriginalText,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Original transcription (Spoken in: ${_selectedSpokenLanguage.name}):", 
                              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey[300]!)
                              ),
                              child: Text(
                                _originalTranscribedText ?? "",
                                style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    
                    Text("Category*", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    DropdownButtonFormField<CategoryModel>( 
                      decoration: const InputDecoration(
                        hintText: 'Select Category',
                      ),
                      value: _selectedCategoryModel,
                      isExpanded: true,
                      items: _fetchedCategories.map((CategoryModel category) {
                        return DropdownMenuItem<CategoryModel>(
                          value: category,
                          child: Text(category.name, style: textTheme.bodyLarge?.copyWith(fontSize: 15)),
                        );
                      }).toList(),
                      onChanged: (CategoryModel? newValue) {
                        setState(() {
                          _selectedCategoryModel = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a category.' : null,
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    
                    Text("AI Detected Urgency", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _isDetectingUrgency ? Colors.yellow[50] : (_detectedUrgency == null ? Colors.grey[100] : Colors.blue[50]),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: _isDetectingUrgency ? Colors.orange.shade300 : (_detectedUrgency == null ? Colors.grey[350]! : Colors.blue.shade300) )
                      ),
                      child: Text(
                        _isDetectingUrgency ? 'Analyzing urgency...' : (_detectedUrgency ?? 'Urgency not yet determined'),
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 15, 
                          color: _isDetectingUrgency ? Colors.orange.shade800 : (_detectedUrgency == null ? Colors.grey[700] : Colors.blue.shade800),
                          fontStyle: _detectedUrgency == null && !_isDetectingUrgency ? FontStyle.italic : FontStyle.normal,
                          fontWeight: _detectedUrgency != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    Text("Tags (Optional, comma-separated)", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(height: screenHeight * 0.008),
                    CustomTextField(
                      controller: _tagsController,
                      hintText: 'e.g., broken, urgent, road_hazard',
                      maxLines: 1,
                      keyboardType: TextInputType.text,
                    ),
                    SizedBox(height: screenHeight * 0.05),

                    AuthButton(
                      text: 'Submit Report',
                      onPressed: (_isLoadingInitialData || isAnyProcessing) ? null : _submitReport,
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
