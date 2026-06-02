import 'dart:convert';
import 'dart:typed_data';

/// Types of logged interactions with a contact.
enum InteractionType { call, text, email, meeting, note }

/// A single timestamped interaction with a contact (call, text, meeting, …).
class InteractionEvent {
  final String id;
  final DateTime date;
  final InteractionType type;
  final String note;

  const InteractionEvent({
    required this.id,
    required this.date,
    required this.type,
    this.note = '',
  });

  factory InteractionEvent.fromJson(Map<String, dynamic> json) {
    return InteractionEvent(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      type: InteractionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => InteractionType.note,
      ),
      note: (json['note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'note': note,
      };
}

class Contact {
  final String id;
  final String firstName;
  final String lastName;
  final String workplace;
  final String homeAddress;
  final String phone;
  final String email;
  final String notes;
  final List<String> tags;
  final String locationMet;
  final double? lat;
  final double? lng;

  /// When you first met / started knowing this contact. Null = unknown, e.g.
  /// for device imports (the OS does not expose a contact's creation date).
  final DateTime? dateMet;
  final List<String> connections;
  final DateTime? lastInteraction;

  /// Chronological log of interactions, newest first.
  final List<InteractionEvent> interactions;

  /// Desired days between reach-outs; null means "use the tag default / off".
  final int? reminderCadenceDays;

  /// Last local modification time, used for sync reconciliation (last-write-wins).
  final DateTime? updatedAt;

  /// Contact photo thumbnail bytes (small), e.g. imported from the device
  /// address book. Null when there is no picture. Persisted as base64.
  final Uint8List? photoThumbnail;

  /// The contact's birthday, when known (e.g. imported from the device).
  final DateTime? birthday;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.workplace = '',
    this.homeAddress = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
    required this.tags,
    required this.locationMet,
    this.lat,
    this.lng,
    this.dateMet,
    required this.connections,
    this.lastInteraction,
    this.interactions = const [],
    this.reminderCadenceDays,
    this.updatedAt,
    this.photoThumbnail,
    this.birthday,
  });

  /// Whether this contact has a photo thumbnail available.
  bool get hasPhoto => photoThumbnail != null && photoThumbnail!.isNotEmpty;

  String get displayName => '$firstName $lastName'.trim();

  /// Returns a copy with the given fields replaced. Pass a field to change it;
  /// omit it to keep the current value.
  Contact copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? workplace,
    String? homeAddress,
    String? phone,
    String? email,
    String? notes,
    List<String>? tags,
    String? locationMet,
    double? lat,
    double? lng,
    DateTime? dateMet,
    List<String>? connections,
    DateTime? lastInteraction,
    List<InteractionEvent>? interactions,
    int? reminderCadenceDays,
    DateTime? updatedAt,
    Uint8List? photoThumbnail,
    DateTime? birthday,
  }) {
    return Contact(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      workplace: workplace ?? this.workplace,
      homeAddress: homeAddress ?? this.homeAddress,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      locationMet: locationMet ?? this.locationMet,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      dateMet: dateMet ?? this.dateMet,
      connections: connections ?? this.connections,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      interactions: interactions ?? this.interactions,
      reminderCadenceDays: reminderCadenceDays ?? this.reminderCadenceDays,
      updatedAt: updatedAt ?? this.updatedAt,
      photoThumbnail: photoThumbnail ?? this.photoThumbnail,
      birthday: birthday ?? this.birthday,
    );
  }

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
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      locationMet: (json['locationMet'] as String?) ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      dateMet: json['dateMet'] != null
          ? DateTime.parse(json['dateMet'] as String)
          : null,
      connections: List<String>.from(json['connections'] ?? []),
      lastInteraction: json['lastInteraction'] != null
          ? DateTime.parse(json['lastInteraction'] as String)
          : null,
      interactions: (json['interactions'] as List<dynamic>?)
              ?.map((e) => InteractionEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reminderCadenceDays: (json['reminderCadenceDays'] as num?)?.toInt(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      photoThumbnail: (json['photoThumbnail'] as String?)?.isNotEmpty == true
          ? base64Decode(json['photoThumbnail'] as String)
          : null,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
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
      'phone': phone,
      'email': email,
      'notes': notes,
      'tags': tags,
      'locationMet': locationMet,
      'lat': lat,
      'lng': lng,
      'dateMet': dateMet?.toIso8601String(),
      'connections': connections,
      'lastInteraction': lastInteraction?.toIso8601String(),
      'interactions': interactions.map((e) => e.toJson()).toList(),
      'reminderCadenceDays': reminderCadenceDays,
      'updatedAt': updatedAt?.toIso8601String(),
      'photoThumbnail':
          photoThumbnail != null ? base64Encode(photoThumbnail!) : null,
      'birthday': birthday?.toIso8601String(),
    };
  }
}

enum PivotType { mutual, location, time }
