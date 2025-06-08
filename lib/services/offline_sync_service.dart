// lib/services/offline_sync_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/issue_model.dart';
import 'dart:developer' as developer;

class OfflineSyncService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Connectivity _connectivity = Connectivity();
  final Uuid _uuid = const Uuid();
  
  bool _isOnline = true;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _pendingIssues = [];
  List<Map<String, dynamic>> _cachedIssues = [];
  String? _currentUserId;
  
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  List<Map<String, dynamic>> get pendingIssues => _pendingIssues;
  List<Map<String, dynamic>> get cachedIssues => _cachedIssues;
  String? get currentUserId => _currentUserId;
  
  OfflineSyncService() {
    _initConnectivity();
    _loadPendingIssues();
    _loadCachedIssues();
    
    // Auto-sync whenever connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result);
      if (_isOnline) {
        syncPendingIssues();
        refreshCachedIssues();
      }
    });
  }
  
  void setCurrentUser(String userId) {
    _currentUserId = userId;
    developer.log('OfflineSyncService: Current user set to $userId', name: 'OfflineSyncService');
    
    // Try to sync any pending issues and refresh cache when user is set
    if (_isOnline) {
      syncPendingIssues();
      refreshCachedIssues();
    }
    notifyListeners();
  }
  
  Future<void> _initConnectivity() async {
    try {
      var connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
      
      _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    } catch (e) {
      developer.log('Error initializing connectivity: $e', name: 'OfflineSyncService');
      _isOnline = false;
    }
    notifyListeners();
  }
  
  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    if (!wasOnline && _isOnline) {
      // We just came back online, try to sync pending issues
      syncPendingIssues();
    }
    
    notifyListeners();
  }
  
  Future<void> _loadPendingIssues() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/pending_issues.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(jsonString);
        _pendingIssues = decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      developer.log('Error loading pending issues: $e', name: 'OfflineSyncService');
    }
    notifyListeners();
  }
  
  Future<void> _savePendingIssues() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/pending_issues.json');
      
      await file.writeAsString(jsonEncode(_pendingIssues));
    } catch (e) {
      developer.log('Error saving pending issues: $e', name: 'OfflineSyncService');
    }
  }
  
  Future<void> _loadCachedIssues() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cached_issues.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(jsonString);
        _cachedIssues = decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      developer.log('Error loading cached issues: $e', name: 'OfflineSyncService');
    }
    notifyListeners();
  }
  
  Future<void> _saveCachedIssues() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/cached_issues.json');
      
      await file.writeAsString(jsonEncode(_cachedIssues));
    } catch (e) {
      developer.log('Error saving cached issues: $e', name: 'OfflineSyncService');
    }
  }
  
  Future<void> cacheIssues(List<Issue> issues) async {
    final issuesData = issues.map((issue) => {
      ...issue.toMap(),
      'id': issue.id,
    }).toList();
    
    _cachedIssues = issuesData;
    await _saveCachedIssues();
    notifyListeners();
  }
  
  Future<String?> saveIssueOffline({
    required String description,
    required String category,
    required String? urgency,
    required List<String>? tags,
    required String imagePath,
    required LocationModel location,
    required String userId,
    required String username,
  }) async {
    try {
      final tempId = 'offline_${_uuid.v4()}';
      final now = DateTime.now();
      
      developer.log('Saving issue offline with tempId: $tempId', name: 'OfflineSyncService');
      
      // First, copy the image to app documents directory for persistence
      final directory = await getApplicationDocumentsDirectory();
      final localImageDir = Directory('${directory.path}/offline_images');
      
      if (!await localImageDir.exists()) {
        await localImageDir.create(recursive: true);
      }
      
      final localImagePath = '${localImageDir.path}/$tempId.jpg';
      final originalImage = File(imagePath);
      await originalImage.copy(localImagePath);
      
      developer.log('Copied image to local storage: $localImagePath', name: 'OfflineSyncService');
      
      // Create issue data map
      final issueData = {
        'id': tempId, // Temporary ID until we sync
        'description': description,
        'category': category,
        'urgency': urgency ?? 'medium',
        'tags': tags ?? [],
        'imagePath': localImagePath, // Local path to the image
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': location.address,
        },
        'userId': userId,
        'username': username,
        'status': 'Pending Upload',
        'timestamp': now.millisecondsSinceEpoch,
        'isOffline': true,
        'departmentAssigned': '', // Default empty values for required fields
        'title': description.substring(0, description.length > 50 ? 50 : description.length),
        'lastStatusUpdate': now.millisecondsSinceEpoch,
        'peopleAffected': 1,
      };
      
      // Add to pending issues list
      _pendingIssues.add(issueData);
      await _savePendingIssues();
      
      // Also add to cached issues for viewing while offline
      _cachedIssues.add(issueData);
      await _saveCachedIssues();
      
      developer.log('Issue saved offline successfully', name: 'OfflineSyncService');
      notifyListeners();
      return tempId;
    } catch (e) {
      developer.log('Error saving issue offline: $e', name: 'OfflineSyncService');
      return null;
    }
  }
  
  Future<bool> syncPendingIssues() async {
    if (_pendingIssues.isEmpty || !_isOnline || _isSyncing) {
      return false;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    bool allSynced = true;
    List<Map<String, dynamic>> remainingPendingIssues = [];
    
    for (final issueData in _pendingIssues) {
      try {
        // Upload the image to Firebase Storage
        final localImagePath = issueData['imagePath'] as String;
        final imageFile = File(localImagePath);
        
        if (await imageFile.exists()) {
          final storageRef = _storage.ref().child('issue_images/${issueData['tempId']}.jpg');
          await storageRef.putFile(imageFile);
          final imageUrl = await storageRef.getDownloadURL();
          
          // Create the issue in Firestore
          final issueRef = _firestore.collection('issues').doc();
          
          final firestoreData = {
            ...issueData,
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
          };
          
          // Remove local-only fields
          firestoreData.remove('tempId');
          firestoreData.remove('imagePath');
          
          await issueRef.set(firestoreData);
          
          // Update cached issues
          final index = _cachedIssues.indexWhere((i) => i['id'] == issueData['tempId']);
          if (index != -1) {
            _cachedIssues.removeAt(index);
          }
        } else {
          developer.log('Local image not found: $localImagePath', name: 'OfflineSyncService');
          remainingPendingIssues.add(issueData);
          allSynced = false;
        }
      } catch (e) {
        developer.log('Error syncing issue: $e', name: 'OfflineSyncService');
        remainingPendingIssues.add(issueData);
        allSynced = false;
      }
    }
    
    _pendingIssues = remainingPendingIssues;
    await _savePendingIssues();
    await _saveCachedIssues();
    
    _isSyncing = false;
    notifyListeners();
    
    return allSynced;
  }
  
  List<Issue> getCombinedIssues() {
    List<Issue> combinedIssues = [];
    
    // Convert cached online issues
    for (final issueData in _cachedIssues.where((i) => i['isOffline'] != true)) {
      try {
        final issue = Issue.fromFirestore(issueData, issueData['id'] as String);
        combinedIssues.add(issue);
      } catch (e) {
        developer.log('Error converting cached issue: $e', name: 'OfflineSyncService');
      }
    }
    
    // Convert pending offline issues
    for (final issueData in _cachedIssues.where((i) => i['isOffline'] == true)) {
      try {
        final Map<String, dynamic> offlineIssueData = {
          ...issueData,
          'status': 'Pending Upload',
        };
        
        final issue = Issue.fromFirestore(offlineIssueData, issueData['id'] as String);
        combinedIssues.add(issue);
      } catch (e) {
        developer.log('Error converting offline issue: $e', name: 'OfflineSyncService');
      }
    }
    
    // Sort by timestamp (newest first)
    combinedIssues.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return combinedIssues;
  }
  
  Future<void> refreshCachedIssues() async {
    if (!_isOnline) return;
    
    try {
      final snapshot = await _firestore.collection('issues').orderBy('timestamp', descending: true).limit(50).get();
      
      final onlineIssues = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
      
      // Keep offline issues, replace online ones
      final offlineIssues = _cachedIssues.where((i) => i['isOffline'] == true).toList();
      _cachedIssues = [...onlineIssues, ...offlineIssues];
      
      await _saveCachedIssues();
      notifyListeners();
    } catch (e) {
      developer.log('Error refreshing cached issues: $e', name: 'OfflineSyncService');
    }
  }
}
