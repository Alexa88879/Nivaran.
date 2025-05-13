// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer; // For logging

class LocationService {
  Future<Position?> getCurrentPosition() async {
    PermissionStatus status = await Permission.locationWhenInUse.request();

    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
         // Consider prompting to open settings, but don't call openAppSettings() directly here
         // Let the UI decide to show a button for that.
         developer.log('Location permission permanently denied.', name: 'LocationService');
      } else {
         developer.log('Location permission denied.', name: 'LocationService');
      }
      throw Exception('Location permission not granted. Status: $status');
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e, s) {
      developer.log('Error getting location: $e', name: 'LocationService', error: e, stackTrace: s);
      throw Exception('Failed to get current location: ${e.toString()}');
    }
  }

  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        // Construct a more readable address
        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
        if (place.postalCode != null && place.postalCode!.isNotEmpty) addressParts.add(place.postalCode!);
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);
        if (place.country != null && place.country!.isNotEmpty) addressParts.add(place.country!);
        
        return addressParts.where((part) => part.isNotEmpty).join(', ');
      }
    } catch (e, s) {
      developer.log('Error getting address: $e', name: 'LocationService', error:e, stackTrace:s);
    }
    return "Address details not found";
  }
}