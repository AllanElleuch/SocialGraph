class Contact {
  final String id;
  final String name;
  final List<String> tags;
  final String locationMet;
  final double? lat;
  final double? lng;
  final DateTime dateMet;
  final List<String> connections;
  final DateTime? lastInteraction;

  Contact({
    required this.id,
    required this.name,
    required this.tags,
    required this.locationMet,
    this.lat,
    this.lng,
    required this.dateMet,
    required this.connections,
    this.lastInteraction,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      name: json['name'] as String,
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
      'name': name,
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
