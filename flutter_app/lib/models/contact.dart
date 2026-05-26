class Contact {
  final String id;
  final String firstName;
  final String lastName;
  final String workplace;
  final String homeAddress;
  final List<String> tags;
  final String locationMet;
  final double? lat;
  final double? lng;
  final DateTime dateMet;
  final List<String> connections;
  final DateTime? lastInteraction;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.workplace = '',
    this.homeAddress = '',
    required this.tags,
    required this.locationMet,
    this.lat,
    this.lng,
    required this.dateMet,
    required this.connections,
    this.lastInteraction,
  });

  String get displayName => '$firstName $lastName'.trim();

  factory Contact.fromJson(Map<String, dynamic> json) {
    String firstName;
    String lastName;
    if (json.containsKey('firstName')) {
      firstName = json['firstName'] as String;
      lastName = (json['lastName'] as String?) ?? '';
    } else {
      final name = (json['name'] as String?) ?? '';
      final spaceIndex = name.indexOf(' ');
      if (spaceIndex == -1) {
        firstName = name;
        lastName = '';
      } else {
        firstName = name.substring(0, spaceIndex);
        lastName = name.substring(spaceIndex + 1);
      }
    }

    return Contact(
      id: json['id'] as String,
      firstName: firstName,
      lastName: lastName,
      workplace: (json['workplace'] as String?) ?? '',
      homeAddress: (json['homeAddress'] as String?) ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      locationMet: json['locationMet'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      dateMet: DateTime.parse(json['dateMet'] as String),
      connections: List<String>.from(json['connections'] ?? []),
      lastInteraction: json['lastInteraction'] != null
          ? DateTime.parse(json['lastInteraction'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'workplace': workplace,
      'homeAddress': homeAddress,
      'tags': tags,
      'locationMet': locationMet,
      'lat': lat,
      'lng': lng,
      'dateMet': dateMet.toIso8601String(),
      'connections': connections,
      'lastInteraction': lastInteraction?.toIso8601String(),
    };
  }
}

enum PivotType { mutual, location, time }
