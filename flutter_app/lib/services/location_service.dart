import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/address_suggestion.dart';

class LocationService {
  static const _userAgent = 'SocialGraph/1.0';

  Future<({double lat, double lng})> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission denied. Please grant location access in Settings.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Please enable it in System Settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition();
    return (lat: position.latitude, lng: position.longitude);
  }

  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final response = await http.get(uri, headers: {'User-Agent': _userAgent});
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['display_name'] as String;
    } catch (_) {
      return '$lat, $lng';
    }
  }

  Future<List<AddressSuggestion>> searchAddress(String query) async {
    if (query.length < 3) {
      return [];
    }
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
      );
      final response = await http.get(uri, headers: {'User-Agent': _userAgent});
      final items = json.decode(response.body) as List<dynamic>;
      return items.map((item) {
        final map = item as Map<String, dynamic>;
        return AddressSuggestion(
          displayName: map['display_name'] as String,
          lat: double.parse(map['lat'] as String),
          lng: double.parse(map['lon'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
