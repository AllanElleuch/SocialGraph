import 'dart:convert';
import 'dart:typed_data';

import '../utils/text_sanitizer.dart';

/// Tag the importer attaches to device-imported contacts. It predates the
/// structured [ContactOrigin] provenance, so it also serves as a legacy signal
/// that a contact came from an import (see [Contact.wasImported]).
const String kImportedTag = 'Imported';

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
      note: sanitizeUtf16((json['note'] as String?) ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'note': note,
      };
}

/// Records how a [Contact] entered the app: created by hand (`manual`) or
/// imported from a device address book. For imports it also captures which
/// platform it came from, the stable device id (so the same address-book entry
/// can be recognised on re-import), and when the import happened.
class ContactOrigin {
  /// `'manual'` for hand-created contacts, `'imported'` for device imports.
  final String source;

  /// Where an imported contact came from, e.g. `'iOS'` or `'Android'`. Empty
  /// for manual contacts.
  final String platform;

  /// Stable device address-book id of an imported contact, used to recognise
  /// the same person on re-import (idempotency). Empty for manual contacts.
  final String deviceId;

  /// When the contact was imported. Null for manual contacts.
  final DateTime? importedAt;

  const ContactOrigin({
    this.source = 'manual',
    this.platform = '',
    this.deviceId = '',
    this.importedAt,
  });

  /// A hand-created contact with no import provenance.
  static const ContactOrigin manual = ContactOrigin();

  /// Builds provenance for a device import.
  factory ContactOrigin.imported({
    String platform = '',
    String deviceId = '',
    DateTime? importedAt,
  }) =>
      ContactOrigin(
        source: 'imported',
        platform: platform,
        deviceId: deviceId,
        importedAt: importedAt,
      );

  bool get isImported => source == 'imported';

  Map<String, dynamic> toJson() => {
        'source': source,
        if (platform.isNotEmpty) 'platform': platform,
        if (deviceId.isNotEmpty) 'deviceId': deviceId,
        if (importedAt != null) 'importedAt': importedAt!.toIso8601String(),
      };

  factory ContactOrigin.fromJson(Map<String, dynamic> json) => ContactOrigin(
        source: (json['source'] as String?) ?? 'manual',
        platform: sanitizeUtf16((json['platform'] as String?) ?? ''),
        deviceId: (json['deviceId'] as String?) ?? '',
        importedAt: json['importedAt'] != null
            ? DateTime.tryParse(json['importedAt'] as String)
            : null,
      );
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

  /// How this contact entered the app (manual vs. imported, and import
  /// provenance). Null for contacts created before provenance was tracked.
  final ContactOrigin? origin;

  /// Social media handles keyed by platform id (e.g. `{'instagram': 'ada'}`).
  /// Handles are stored bare; see `SocialPlatform` for the supported keys and
  /// profile-URL building.
  final Map<String, String> socials;

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
    this.origin,
    this.socials = const {},
  });

  /// Whether this contact has a photo thumbnail available.
  bool get hasPhoto => photoThumbnail != null && photoThumbnail!.isNotEmpty;

  /// Whether this contact came from a device import — via structured provenance
  /// ([origin]), or, for contacts imported before provenance existed, the
  /// legacy [kImportedTag] tag. Use this (not `origin?.isImported` alone) so
  /// legacy imports are still classified correctly.
  bool get wasImported =>
      origin?.isImported == true || tags.contains(kImportedTag);

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
    ContactOrigin? origin,
    Map<String, String>? socials,
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
      origin: origin ?? this.origin,
      socials: socials ?? this.socials,
    );
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    String firstName;
    String lastName;
    if (json.containsKey('firstName')) {
      firstName = sanitizeUtf16(json['firstName'] as String);
      lastName = sanitizeUtf16((json['lastName'] as String?) ?? '');
    } else {
      final name = sanitizeUtf16((json['name'] as String?) ?? '');
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
      workplace: sanitizeUtf16((json['workplace'] as String?) ?? ''),
      homeAddress: sanitizeUtf16((json['homeAddress'] as String?) ?? ''),
      phone: sanitizeUtf16((json['phone'] as String?) ?? ''),
      email: sanitizeUtf16((json['email'] as String?) ?? ''),
      notes: sanitizeUtf16((json['notes'] as String?) ?? ''),
      tags: List<String>.from(json['tags'] ?? [])
          .map(sanitizeUtf16)
          .toList(),
      locationMet: sanitizeUtf16((json['locationMet'] as String?) ?? ''),
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
      origin: json['origin'] is Map<String, dynamic>
          ? ContactOrigin.fromJson(json['origin'] as Map<String, dynamic>)
          : null,
      socials: (json['socials'] as Map?)?.map(
            (key, value) => MapEntry(
              key.toString(),
              sanitizeUtf16(value?.toString() ?? ''),
            ),
          ) ??
          const {},
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
      'origin': origin?.toJson(),
      if (socials.isNotEmpty) 'socials': socials,
    };
  }
}

enum PivotType { mutual, location, time, stats }
