import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Request location permission with a user-friendly dialog
  static Future<bool> requestLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Show user-friendly dialog explaining why we need location
      bool shouldRequest =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('Location Permission'),
                  content: Text(
                    'LawLink needs your location to find legal services near you. '
                    'This helps us suggest the closest courts, legal aid offices, or law firms based on your query.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Deny'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Allow'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade500,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!shouldRequest) {
        return false;
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Show dialog to guide user to app settings
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Location Permission Required'),
              content: Text(
                'Location permission has been permanently denied. '
                'Please enable it in your app settings to use location-based features in LawLink.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Geolocator.openAppSettings();
                  },
                  child: Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade500,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
      );
      return false;
    }

    return true;
  }

  // Get current location
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Convert coordinates to address
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }
}
