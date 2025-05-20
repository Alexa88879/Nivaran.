// lib/screens/feed/issues_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:developer' as developer; 

import '../../widgets/issue_card.dart'; // Uses IssueCard
import '../../models/issue_model.dart';
import '../../services/location_service.dart';

class IssuesListScreen extends StatefulWidget {
  const IssuesListScreen({super.key});

  @override
  State<IssuesListScreen> createState() => _IssuesListScreenState();
}

class _IssuesListScreenState extends State<IssuesListScreen> {
  String _currentLocationDisplay = "Nearby";
  bool _isFetchingLocation = false;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocationAndUpdateDisplay();
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is permanently denied. Please enable it in settings.'),
            action: SnackBarAction(label: 'Open Settings', onPressed: openAppSettings),
          ),
        );
      }
    }
  }

  Future<void> _fetchCurrentLocationAndUpdateDisplay() async {
    if (!mounted) return;
    setState(() {
      _isFetchingLocation = true;
      _currentLocationDisplay = "Fetching location..."; 
    });

    await _requestLocationPermission(); 

    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Showing general feed.')),
        );
        setState(() {
          _currentLocationDisplay = "All Issues";
          _isFetchingLocation = false;
        });
      }
      return;
    }

    try {
      final Position? position = await _locationService.getCurrentPosition(); 

      if (position != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (mounted && placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;
          String displayAddress = "";

          if (place.street != null && place.street!.isNotEmpty) {
            displayAddress += place.street!;
          } else if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
            displayAddress += place.thoroughfare!;
          }
          
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            if (displayAddress.isNotEmpty) displayAddress += ", ";
            displayAddress += place.subLocality!;
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            if (displayAddress.isNotEmpty) displayAddress += ", ";
            displayAddress += place.locality!;
          }

          if (displayAddress.isEmpty) { 
            displayAddress = place.locality ?? place.administrativeArea ?? "Current Location";
          }
          
          if (displayAddress.length > 30) {
            displayAddress = '${displayAddress.substring(0, 27)}...';
          }

          setState(() {
            _currentLocationDisplay = displayAddress.isNotEmpty ? displayAddress : "Unnamed Area";
          });
        } else if (mounted) {
          setState(() {
            _currentLocationDisplay = "Current Location"; 
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not fetch location data.')),
        );
        setState(() {
          _currentLocationDisplay = "Location Unavailable";
        });
      }
    } catch (e) {
      developer.log('Error fetching location in IssuesListScreen: ${e.toString()}', name: 'IssuesListScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error determining location: Check permissions and services.')),
        );
        setState(() {
          _currentLocationDisplay = "Location Error";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isFetchingLocation ? "Updating location..." : _currentLocationDisplay,
                style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('issues')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isFetchingLocation) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            developer.log('Firestore Error: ${snapshot.error}', name: 'IssuesListScreen');
            return const Center(child: Text('Error loading issues. Please try again.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No issues reported yet. Be the first!'));
          }

          final issuesDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: issuesDocs.length,
            itemBuilder: (context, index) {
              final issueData = issuesDocs[index].data() as Map<String, dynamic>;
              final issueId = issuesDocs[index].id;
              final issue = Issue.fromFirestore(issueData, issueId);
              // Each issue is rendered using IssueCard, which handles image display
              return IssueCard(issue: issue); 
            },
          );
        },
      ),
    );
  }
}
