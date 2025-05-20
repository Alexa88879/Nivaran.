// lib/screens/map/map_view_screen.dart
import 'dart:async';
//import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../../models/issue_model.dart';
import '../../models/category_model.dart'; // For CategoryModel
import '../../services/location_service.dart';
import '../../services/firestore_service.dart'; // For fetching categories
import '../../widgets/issue_card.dart';
import '../report/camera_capture_screen.dart';
import 'dart:developer' as developer;

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _loadingMessage = "Initializing map...";
  Set<Marker> _markers = {};
  StreamSubscription<QuerySnapshot>? _issuesSubscription;
  Issue? _selectedIssue;

  String? _selectedFilterCategory;
  String? _selectedFilterUrgency;
  String? _selectedFilterStatus;
  List<CategoryModel> _fetchedFilterCategories = [];
  final FirestoreService _firestoreService = FirestoreService();
  final List<String> _allUrgencyLevels = ['Low', 'Medium', 'High'];
  final List<String> _allStatuses = ['Reported', 'Acknowledged', 'In Progress', 'Resolved', 'Rejected'];

  static const CameraPosition _kInitialCameraPosition = CameraPosition(
    target: LatLng(28.6692, 77.4538), // Approx. Ghaziabad
    zoom: 12.0,
  );

  final Map<String, BitmapDescriptor> _markerIconCache = {};

  @override
  void initState() {
    super.initState();
    developer.log("MapViewScreen: initState", name: "MapViewScreen");
    _initializeMapAndLocation();
    _fetchFilterCategoriesForDialog();
  }

  Future<void> _fetchFilterCategoriesForDialog() async {
    if (!mounted) return;
    try {
      final categories = await _firestoreService.fetchIssueCategories();
      if (mounted) {
        setState(() {
          _fetchedFilterCategories = categories;
        });
        if (categories.isEmpty) {
          developer.log("No active categories fetched for filter dialog.", name: "MapViewScreen");
        }
      }
    } catch (e) {
      developer.log("Error fetching categories for filter: $e", name: "MapViewScreen");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not load filter categories."))
        );
      }
    }
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
          if (_mapController != null) _animateToUserLocation();
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

  Future<BitmapDescriptor> _createCircularMarkerBitmap(String imageUrl, {int size = 150}) async {
    if (_markerIconCache.containsKey(imageUrl)) {
      return _markerIconCache[imageUrl]!;
    }
    try {
      final http.Response response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        developer.log("Failed to fetch image for marker: $imageUrl, Status: ${response.statusCode}", name: "MapViewScreen");
        return _getCategoryMarkerColor('default');
      }
      final Uint8List imageBytes = response.bodyBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes, targetWidth: size, targetHeight: size);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final double radius = size / 2;
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius)));
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
      final ui.Picture picture = pictureRecorder.endRecording();
      final ui.Image img = await picture.toImage(size, size);
      final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        developer.log("Failed to convert picture to ByteData for $imageUrl", name: "MapViewScreen");
        return _getCategoryMarkerColor('default');
      }
      final Uint8List markerBytes = byteData.buffer.asUint8List();
      // ignore: deprecated_member_use_from_same_package
      final BitmapDescriptor bitmapDescriptor = BitmapDescriptor.bytes(markerBytes);
      _markerIconCache[imageUrl] = bitmapDescriptor;
      return bitmapDescriptor;
    } catch (e) {
      developer.log("Error creating circular marker for $imageUrl: $e", name: "MapViewScreen");
      return _getCategoryMarkerColor('default');
    }
  }

  void _fetchIssuesAndSetupListener() {
    developer.log("MapViewScreen: Setting up issues stream listener. Filters: Cat:$_selectedFilterCategory, Urg:$_selectedFilterUrgency, Stat:$_selectedFilterStatus", name: "MapViewScreen");
    _issuesSubscription?.cancel();

    Query query = FirebaseFirestore.instance.collection('issues');

    if (_selectedFilterCategory != null) {
      query = query.where('category', isEqualTo: _selectedFilterCategory);
    }
    if (_selectedFilterUrgency != null) {
      query = query.where('urgency', isEqualTo: _selectedFilterUrgency);
    }
    if (_selectedFilterStatus != null) {
      query = query.where('status', isEqualTo: _selectedFilterStatus);
    }
    query = query.orderBy('timestamp', descending: true);

    _issuesSubscription = query.snapshots().listen((snapshot) async {
      if (!mounted) return;
      developer.log("MapViewScreen: Issues snapshot received with ${snapshot.docs.length} docs.", name: "MapViewScreen");
      Set<Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        try {
          final issue = Issue.fromFirestore(doc.data() as Map<String,dynamic>, doc.id);
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
                onTap: () {
                  if (!mounted) return;
                  setState(() { _selectedIssue = issue; });
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
        setState(() { _markers = newMarkers; });
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
                boxShadow: [
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: IssueCard(issue: issue),
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

  void _showFilterDialog() {
    String? tempCategory = _selectedFilterCategory;
    String? tempUrgency = _selectedFilterUrgency;
    String? tempStatus = _selectedFilterStatus;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter Issues'),
              contentPadding: const EdgeInsets.all(20),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text("Category", style: TextStyle(fontWeight: FontWeight.w500)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(hintText: 'All Categories'),
                      value: tempCategory,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Categories')),
                        ..._fetchedFilterCategories.map((CategoryModel category) {
                          return DropdownMenuItem<String>(
                            value: category.name,
                            child: Text(category.name),
                          );
                        })
                      ],
                      onChanged: (String? newValue) {
                        setDialogState(() => tempCategory = newValue);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("Urgency", style: TextStyle(fontWeight: FontWeight.w500)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(hintText: 'All Urgencies'),
                      value: tempUrgency,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Urgencies')),
                        ..._allUrgencyLevels.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                      ],
                      onChanged: (String? newValue) {
                        setDialogState(() => tempUrgency = newValue);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("Status", style: TextStyle(fontWeight: FontWeight.w500)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(hintText: 'All Statuses'),
                      value: tempStatus,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Statuses')),
                        ..._allStatuses.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                      ],
                      onChanged: (String? newValue) {
                        setDialogState(() => tempStatus = newValue);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Clear All'),
                  onPressed: () {
                    if(mounted) {
                      setState(() {
                        _selectedFilterCategory = null;
                        _selectedFilterUrgency = null;
                        _selectedFilterStatus = null;
                        _fetchIssuesAndSetupListener();
                      });
                    }
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Apply Filters'),
                  onPressed: () {
                    if(mounted) {
                      setState(() {
                        _selectedFilterCategory = tempCategory;
                        _selectedFilterUrgency = tempUrgency;
                        _selectedFilterStatus = tempStatus;
                        _fetchIssuesAndSetupListener();
                      });
                    }
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  void dispose() {
    developer.log("MapViewScreen: dispose", name: "MapViewScreen");
    _issuesSubscription?.cancel();
    _mapController?.dispose();
    _markerIconCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Get MediaQuery padding for safe area adjustments
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    final double topPadding = mediaQueryData.padding.top;
    // final double bottomPadding = mediaQueryData.padding.bottom; // For FAB if it were at the bottom

    // The Scaffold is now the root widget of this screen's build method.
    // SafeArea is handled more granularly for overlaid elements.
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialCameraPosition,
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Disable default one, we can add a custom one if needed
            markers: _markers,
            zoomControlsEnabled: false, // Disable default zoom controls, can add custom ones
            // Adjust GoogleMap's own UI elements (like compass, if enabled)
            // and the visual viewport of the map data itself.
            padding: EdgeInsets.only(
              top: topPadding + 10, // Add a little extra space below status bar for map elements
              bottom: _selectedIssue != null ? MediaQuery.of(context).size.height * 0.35 : 0,
            ),
            onTap: (_) {
              if (_selectedIssue != null) {
                Navigator.of(context).pop();
                 if (mounted) {
                    setState(() { _selectedIssue = null; });
                  }
              }
            },
            onLongPress: (LatLng latLng) {
              _showReportHereDialog(latLng);
            },
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha((0.5 * 255).round()),
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
          // Positioned UI elements that need to respect the safe area
          Positioned(
            top: topPadding + 10, // Position FAB below status bar
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _showFilterDialog,
              backgroundColor: Colors.white,
              tooltip: 'Filter Issues',
              child: Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
            ),
          ),
          // Custom "My Location" Button
           Positioned(
            top: topPadding + 10, // Align with filter button or adjust
            left: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _currentPosition != null ? _animateToUserLocation : null,
              backgroundColor: Colors.white,
              tooltip: 'My Location',
              child: Icon(Icons.my_location, color: _currentPosition != null ? Theme.of(context).primaryColor : Colors.grey),
            ),
          ),
          // Custom Zoom Buttons
          Positioned(
            bottom: (_selectedIssue != null ? MediaQuery.of(context).size.height * 0.35 : 0) + 20, // Above bottom sheet or bottom edge
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoomInButton', // Unique heroTag
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  backgroundColor: Colors.white,
                  child: Icon(Icons.add, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoomOutButton', // Unique heroTag
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  backgroundColor: Colors.white,
                  child: Icon(Icons.remove, color: Theme.of(context).primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReportHereDialog(LatLng coordinates) async {
    if (!mounted) return;
    String address = "Selected Location";
    try {
      final LocationService locationService = LocationService();
      address = await locationService.getAddressFromCoordinates(coordinates.latitude, coordinates.longitude) ?? address;
    } catch (e) {
      developer.log("Could not get address for long-press: $e", name: "MapViewScreen");
    }
if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Report New Issue"),
          content: Text("Do you want to report a new issue at this location?\n\n$address"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Proceed to Report"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraCaptureScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
