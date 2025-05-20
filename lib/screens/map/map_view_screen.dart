// lib/screens/map/map_view_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http; // Import http package
import 'package:path_provider/path_provider.dart'; // For potential image caching
import 'dart:io'; // For File operations

import 'package:permission_handler/permission_handler.dart';
// import 'package:provider/provider.dart'; // Not directly used in this file for now
import '../../models/issue_model.dart';
import '../../services/location_service.dart';
// import '../../services/user_profile_service.dart'; // For user context if needed
import '../../widgets/issue_card.dart'; // For displaying issue details in bottom sheet
import 'dart:developer' as developer;

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Preserve state when switching tabs

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _loadingMessage = "Initializing map...";
  Set<Marker> _markers = {};
  StreamSubscription<QuerySnapshot>? _issuesSubscription;
  Issue? _selectedIssue;

  static const CameraPosition _kInitialCameraPosition = CameraPosition(
    target: LatLng(28.6692, 77.4538), // Approx. Ghaziabad
    zoom: 12.0,
  );

  // Cache for bitmap descriptors to avoid re-creating them
  final Map<String, BitmapDescriptor> _markerIconCache = {};


  @override
  void initState() {
    super.initState();
    developer.log("MapViewScreen: initState", name: "MapViewScreen");
    _initializeMapAndLocation();
  }

  Future<void> _initializeMapAndLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingMessage = "Checking location permissions...";
    });

    final LocationService locationService = LocationService();
    try {
      PermissionStatus status = await Permission.locationWhenInUse.request();
      if (!mounted) return;

      if (status.isGranted) {
        _loadingMessage = "Fetching current location...";
        if (mounted) setState(() {});
        _currentPosition = await locationService.getCurrentPosition();
        if (!mounted) return;

        if (_currentPosition != null) {
          _loadingMessage = "Loading map...";
           if (mounted) setState(() {});
          _animateToUserLocation();
        } else {
          _loadingMessage = "Could not get location. Showing default area.";
           if (mounted) setState(() {});
        }
      } else {
        _loadingMessage = "Location permission denied. Showing default area.";
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied. Map will show a default area.')),
            );
            if (status.isPermanentlyDenied) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Location permission is permanently denied. Please enable it in app settings.'),
                        action: SnackBarAction(label: 'Open Settings', onPressed: openAppSettings),
                    ),
                );
            }
        }
      }
    } catch (e) {
      developer.log("Error initializing map/location: $e", name: "MapViewScreen");
      _loadingMessage = "Error initializing: ${e.toString().substring(0, (e.toString().length > 50) ? 50 : e.toString().length)}...";
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing map: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _fetchIssuesAndSetupListener();
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    developer.log("MapViewScreen: onMapCreated", name: "MapViewScreen");
    if (!mounted) return;
    _mapController = controller;
    if (_currentPosition != null) {
      _animateToUserLocation();
    }
  }

  void _animateToUserLocation() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  // --- MODIFIED: Function to create circular image markers ---
  Future<BitmapDescriptor> _createCircularMarkerBitmap(String imageUrl, {int size = 150}) async {
    // Check cache first
    if (_markerIconCache.containsKey(imageUrl)) {
      return _markerIconCache[imageUrl]!;
    }

    try {
      final http.Response response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        developer.log("Failed to fetch image for marker: $imageUrl, Status: ${response.statusCode}", name: "MapViewScreen");
        return _getCategoryMarkerColor('default'); // Fallback
      }
      final Uint8List imageBytes = response.bodyBytes;

      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes, targetWidth: size, targetHeight: size);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint();
      final double radius = size / 2;

      // Draw a circular clip
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius)));

      // Draw the image scaled and centered
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );

      // Optional: Add a border
      final Paint borderPaint = Paint()
        ..color = Colors.white // Border color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0; // Border width
      canvas.drawCircle(Offset(radius, radius), radius, borderPaint);


      final ui.Picture picture = pictureRecorder.endRecording();
      final ui.Image img = await picture.toImage(size, size);
      final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        developer.log("Failed to convert picture to ByteData for $imageUrl", name: "MapViewScreen");
        return _getCategoryMarkerColor('default'); // Fallback
      }

      final Uint8List markerBytes = byteData.buffer.asUint8List();
      final BitmapDescriptor bitmapDescriptor = BitmapDescriptor.bytes(markerBytes);
      
      // Cache the descriptor
      _markerIconCache[imageUrl] = bitmapDescriptor;
      return bitmapDescriptor;

    } catch (e) {
      developer.log("Error creating circular marker for $imageUrl: $e", name: "MapViewScreen");
      return _getCategoryMarkerColor('default'); // Fallback to category color
    }
  }


  void _fetchIssuesAndSetupListener() {
    developer.log("MapViewScreen: Setting up issues stream listener.", name: "MapViewScreen");
    _issuesSubscription?.cancel();

    _issuesSubscription = FirebaseFirestore.instance
        .collection('issues')
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;
      developer.log("MapViewScreen: Issues snapshot received with ${snapshot.docs.length} docs.", name: "MapViewScreen");
      Set<Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        try {
          final issue = Issue.fromFirestore(doc.data(), doc.id);
          if (issue.location.latitude != 0.0 && issue.location.longitude != 0.0) {
            
            BitmapDescriptor markerIcon;
            if (issue.imageUrl.isNotEmpty) {
                markerIcon = await _createCircularMarkerBitmap(issue.imageUrl);
            } else {
                markerIcon = _getCategoryMarkerColor(issue.category);
            }

            newMarkers.add(
              Marker(
                markerId: MarkerId(issue.id),
                position: LatLng(issue.location.latitude, issue.location.longitude),
                icon: markerIcon,
                // InfoWindow can be removed if the bottom sheet is preferred for all details
                // infoWindow: InfoWindow(
                //   title: issue.category,
                //   snippet: issue.description.length > 50 ? '${issue.description.substring(0, 50)}...' : issue.description,
                // ),
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    _selectedIssue = issue;
                  });
                  _showIssueDetailsModal(issue);
                },
              ),
            );
          }
        } catch (e) {
          developer.log("Error processing issue doc ${doc.id}: $e", name: "MapViewScreen");
        }
      }
      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    }, onError: (error) {
      developer.log("Error in issues stream: $error", name: "MapViewScreen");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching issues: ${error.toString()}')),
        );
      }
    });
  }

  BitmapDescriptor _getCategoryMarkerColor(String category) {
    switch (category.toLowerCase()) {
      case 'pothole':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      case 'street light out':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      case 'waste management':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'safety hazard':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }


  void _showIssueDetailsModal(Issue issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [ // Optional: Add a subtle shadow
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10.0,
                    spreadRadius: 0.0,
                  )
                ]
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Adjust padding
                      child: IssueCard(issue: issue), // Reusing IssueCard
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _selectedIssue = null;
        });
      }
    });
  }

  @override
  void dispose() {
    developer.log("MapViewScreen: dispose", name: "MapViewScreen");
    _issuesSubscription?.cancel();
    _mapController?.dispose();
    _markerIconCache.clear(); // Clear cache on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialCameraPosition,
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            zoomControlsEnabled: true,
            // Dynamically adjust padding when bottom sheet is visible
            // This helps to "fold" the map by moving its center up.
            padding: EdgeInsets.only(
              bottom: _selectedIssue != null ? MediaQuery.of(context).size.height * 0.35 : 0, // Adjust this factor
            ),
            onTap: (_) { // Dismiss bottom sheet if map is tapped
              if (_selectedIssue != null) {
                Navigator.of(context).pop(); // Assumes bottom sheet is a modal route
                 if (mounted) {
                    setState(() {
                      _selectedIssue = null;
                    });
                  }
              }
            },
            onCameraMove: (CameraPosition position) {
              // You can use this to detect user zooming/panning
              // and potentially load more issues if implementing geo-queries
              // developer.log("Camera moved to: ${position.target}, zoom: ${position.zoom}", name:"MapViewScreen");
            },
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Color.fromRGBO(0, 0, 0, 0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      const SizedBox(height: 16),
                      Text(
                        _loadingMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
