import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';

class ContactService {
  final String baseUrl;

  ContactService({this.baseUrl = 'http://localhost:3000'});

  static final List<Map<String, dynamic>> _seedData = [
    {
      'id': '1',
      'firstName': 'Alice',
      'lastName': 'Johnson',
      'workplace': 'Stripe',
      'homeAddress': '123 Market St, San Francisco, CA',
      'tags': ['Tech', 'Design'],
      'locationMet': 'San Francisco',
      'lat': 37.7749,
      'lng': -122.4194,
      'dateMet': '2023-05-15T10:00:00Z',
      'connections': ['2', '3'],
      'lastInteraction': '2024-01-10T15:00:00Z',
    },
    {
      'id': '2',
      'firstName': 'Bob',
      'lastName': 'Smith',
      'workplace': 'Google',
      'homeAddress': '456 Broadway, New York, NY',
      'tags': ['Engineering'],
      'locationMet': 'New York',
      'lat': 40.7128,
      'lng': -74.0060,
      'dateMet': '2022-11-20T09:00:00Z',
      'connections': ['1', '3'],
      'lastInteraction': '2023-12-05T11:00:00Z',
    },
    {
      'id': '3',
      'firstName': 'Charlie',
      'lastName': 'Brown',
      'workplace': 'Figma',
      'homeAddress': '789 Mission St, San Francisco, CA',
      'tags': ['Product'],
      'locationMet': 'San Francisco',
      'lat': 37.7749,
      'lng': -122.4194,
      'dateMet': '2023-08-01T14:00:00Z',
      'connections': ['1', '2'],
      'lastInteraction': '2024-03-01T10:00:00Z',
    },
  ];

  Future<List<Contact>> fetchContacts() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/contacts'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Contact.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Server unreachable, using seed data: $e');
    }
    // Fallback to seed data when server is unavailable
    return _seedData.map((json) => Contact.fromJson(json)).toList();
  }

  Future<Contact> addContact(Contact contact) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/contacts'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(contact.toJson()),
    );
    if (response.statusCode == 200) {
      return Contact.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to add contact: ${response.statusCode}');
  }

  Future<Contact> updateContact(Contact contact) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/contacts/${contact.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(contact.toJson()),
    );
    if (response.statusCode == 200) {
      return Contact.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to update contact: ${response.statusCode}');
  }

  Future<void> deleteContact(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/contacts/$id'),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete contact: ${response.statusCode}');
    }
  }
}
