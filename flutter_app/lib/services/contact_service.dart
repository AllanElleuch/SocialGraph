import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/contact.dart';

class ContactService {
  final String baseUrl;

  ContactService({this.baseUrl = 'http://localhost:3000'});

  Future<List<Contact>> fetchContacts() async {
    final response = await http.get(Uri.parse('$baseUrl/api/contacts'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Contact.fromJson(json)).toList();
    }
    throw Exception('Failed to load contacts: ${response.statusCode}');
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
}
