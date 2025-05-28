import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/issue_model.dart';
import 'dart:developer' as developer;
import 'dart:math' as math; // Add this import

class PredictiveMaintenance {
  // Singleton pattern
  static final PredictiveMaintenance _instance = PredictiveMaintenance._internal();
  factory PredictiveMaintenance() => _instance;
  PredictiveMaintenance._internal();
  
  // Cache for predictions to avoid recalculating frequently
  List<PredictionCluster>? _cachedPredictions;
  DateTime? _lastPredictionTime;
  
  // Get predictions with caching (refresh every 6 hours)
  Future<List<PredictionCluster>> getPredictions() async {
    final now = DateTime.now();
    if (_cachedPredictions != null && 
        _lastPredictionTime != null && 
        now.difference(_lastPredictionTime!).inHours < 6) {
      return _cachedPredictions!;
    }
    
    final predictions = await _generatePredictions();
    _cachedPredictions = predictions;
    _lastPredictionTime = now;
    return predictions;
  }
  
  // Main prediction generation logic
  Future<List<PredictionCluster>> _generatePredictions() async {
    try {
      // Fetch historical issue data (last 6 months)
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      final snapshot = await FirebaseFirestore.instance
          .collection('issues')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(sixMonthsAgo))
          .get();
      
      if (snapshot.docs.isEmpty) {
        return [];
      }
      
      // Convert to Issue objects
      final issues = snapshot.docs
          .map((doc) => Issue.fromFirestore(doc.data(), doc.id))
          .toList();
      
      // Group issues by location proximity (simple clustering)
      final clusters = _clusterIssuesByLocation(issues);
      
      // Analyze clusters for patterns and generate predictions
      final predictions = _analyzeClustersForPredictions(clusters);
      
      return predictions;
    } catch (e, stackTrace) {
      developer.log(
        'Error generating predictions: $e', 
        name: 'PredictiveMaintenance',
        error: e,
        stackTrace: stackTrace
      );
      return [];
    }
  }
  
  // Group issues by location proximity
  List<IssueCluster> _clusterIssuesByLocation(List<Issue> issues) {
    // Simple clustering algorithm based on geographic proximity
    final List<IssueCluster> clusters = [];
    
    for (final issue in issues) {
      bool addedToCluster = false;
      
      // Try to add to existing cluster
      for (final cluster in clusters) {
        if (_isWithinClusterRadius(issue.location, cluster.centerLocation)) {
          cluster.issues.add(issue);
          // Recalculate center
          cluster.recalculateCenter();
          addedToCluster = true;
          break;
        }
      }
      
      // If not added to any cluster, create a new one
      if (!addedToCluster) {
        clusters.add(IssueCluster(issues: [issue]));
      }
    }
    
    // Filter out clusters with too few issues (not significant)
    return clusters.where((cluster) => cluster.issues.length >= 3).toList();
  }
  
  // Check if a location is within the radius of a cluster
  bool _isWithinClusterRadius(LocationModel location, LocationModel clusterCenter) {
    // Simple distance calculation (Euclidean distance as approximation)
    // For more accuracy, you could use the Haversine formula
    const double clusterRadiusKm = 0.5; // 500 meters radius
    
    final double latDiff = location.latitude - clusterCenter.latitude;
    final double lngDiff = location.longitude - clusterCenter.longitude;
    
    // Rough approximation (1 degree latitude ≈ 111 km)
    final double distanceKm = 
        111 * math.sqrt(latDiff * latDiff + lngDiff * lngDiff); // Changed from dart.math.sqrt
    
    return distanceKm <= clusterRadiusKm;
  }
  
  // Analyze clusters to generate predictions
  List<PredictionCluster> _analyzeClustersForPredictions(List<IssueCluster> clusters) {
    final List<PredictionCluster> predictions = [];
    
    for (final cluster in clusters) {
      // Count issues by category
      final Map<String, int> categoryCounts = {};
      for (final issue in cluster.issues) {
        categoryCounts[issue.category] = (categoryCounts[issue.category] ?? 0) + 1;
      }
      
      // Find most common category
      // Find most common category
      String? mostCommonCategory;
      int maxCount = 0;
      categoryCounts.forEach((category, categoryCount) { // Changed from 'count' to 'categoryCount'
        if (categoryCount > maxCount) {
          maxCount = categoryCount;
          mostCommonCategory = category;
        }
      });
      
      // Calculate recurrence frequency
      final issueTimestamps = cluster.issues
          .map((issue) => issue.timestamp.toDate())
          .toList()
          ..sort();
      
      double averageDaysBetweenIssues = 0;
      if (issueTimestamps.length > 1) {
        int totalDays = 0;
        for (int i = 1; i < issueTimestamps.length; i++) {
          totalDays += issueTimestamps[i].difference(issueTimestamps[i-1]).inDays;
        }
        averageDaysBetweenIssues = totalDays / (issueTimestamps.length - 1);
      }
      
      // Calculate risk score (higher means more likely to recur)
      final int clusterSize = cluster.issues.length;
      final double recurrenceFrequency = averageDaysBetweenIssues > 0 
          ? 30 / averageDaysBetweenIssues // Normalize to monthly frequency
          : 0;
      
      // Risk score formula: cluster size × recurrence frequency
      final double riskScore = clusterSize * recurrenceFrequency;
      
      // Only add significant predictions
      if (riskScore > 5) {
        predictions.add(PredictionCluster(
          centerLocation: cluster.centerLocation,
          category: mostCommonCategory ?? 'Unknown',
          riskScore: riskScore,
          issueCount: clusterSize,
          averageDaysBetweenIssues: averageDaysBetweenIssues,
          // Get a sample address from one of the issues
          address: cluster.issues.first.location.address,
        ));
      }
    }
    
    // Sort by risk score (highest first)
    predictions.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    
    return predictions;
  }
}

// Helper class for clustering issues
class IssueCluster {
  List<Issue> issues;
  late LocationModel centerLocation;
  
  IssueCluster({required this.issues}) {
    recalculateCenter();
  }
  
  void recalculateCenter() {
    if (issues.isEmpty) return;
    
    double sumLat = 0;
    double sumLng = 0;
    
    for (final issue in issues) {
      sumLat += issue.location.latitude;
      sumLng += issue.location.longitude;
    }
    
    centerLocation = LocationModel(
      latitude: sumLat / issues.length,
      longitude: sumLng / issues.length,
      address: issues.first.location.address, // Use first issue's address as reference
    );
  }
}

// Class to represent a prediction cluster
class PredictionCluster {
  final LocationModel centerLocation;
  final String category;
  final double riskScore;
  final int issueCount;
  final double averageDaysBetweenIssues;
  final String address;
  
  PredictionCluster({
    required this.centerLocation,
    required this.category,
    required this.riskScore,
    required this.issueCount,
    required this.averageDaysBetweenIssues,
    required this.address,
  });
  
  String get formattedRiskScore => riskScore.toStringAsFixed(1);
  
  String get recurrencePattern {
    if (averageDaysBetweenIssues < 7) {
      return 'Weekly';
    } else if (averageDaysBetweenIssues < 30) {
      return 'Monthly';
    } else if (averageDaysBetweenIssues < 90) {
      return 'Quarterly';
    } else {
      return 'Infrequent';
    }
  }
}