import 'dart:convert';
import 'dart:typed_data';

import 'contact.dart';

/// A high-fidelity snapshot of a device address-book entry.
///
/// Unlike the app's [Contact] (which keeps a single phone/email/address for
/// display), [ImportedContact] preserves *everything* the OS exposes for a
/// contact — every labeled phone/email/address, organizations, websites,
/// social profiles, events (birthdays/anniversaries), relations, notes, and
/// the contact photo. The plugin → model mapping lives in
/// `ContactsImportService`; this model itself is plugin-agnostic plain Dart so
/// it can be persisted, tested, and reused independently.
class ImportedContact {
  /// The device's stable contact identifier (iOS/Android).
  final String sourceId;
  final String displayName;

  // Structured name.
  final String first;
  final String middle;
  final String last;
  final String prefix;
  final String suffix;
  final String nickname;
  final String phoneticFirst;
  final String phoneticMiddle;
  final String phoneticLast;

  final ContactPhoto? photo;

  final List<LabeledValue> phones;
  final List<LabeledValue> emails;
  final List<PostalAddress> addresses;
  final List<ContactOrganization> organizations;
  final List<LabeledValue> websites;
  final List<LabeledValue> socialMedias;
  final List<ContactEvent> events;
  final List<LabeledValue> relations;

  /// Free-form notes. Empty on iOS unless the app holds the
  /// `com.apple.developer.contacts.notes` entitlement and notes are enabled.
  final List<String> notes;

  const ImportedContact({
    required this.sourceId,
    this.displayName = '',
    this.first = '',
    this.middle = '',
    this.last = '',
    this.prefix = '',
    this.suffix = '',
    this.nickname = '',
    this.phoneticFirst = '',
    this.phoneticMiddle = '',
    this.phoneticLast = '',
    this.photo,
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.organizations = const [],
    this.websites = const [],
    this.socialMedias = const [],
    this.events = const [],
    this.relations = const [],
    this.notes = const [],
  });

  String get primaryPhone => phones.isNotEmpty ? phones.first.value : '';
  String get primaryEmail => emails.isNotEmpty ? emails.first.value : '';
  PostalAddress? get primaryAddress =>
      addresses.isNotEmpty ? addresses.first : null;
  ContactOrganization? get primaryOrganization =>
      organizations.isNotEmpty ? organizations.first : null;

  /// The best available photo bytes (full-resolution preferred, else thumbnail).
  Uint8List? get bestPhoto => photo?.fullSize ?? photo?.thumbnail;

  /// The first birthday event, if any.
  ContactEvent? get birthday {
    for (final e in events) {
      if (e.isBirthday) return e;
    }
    return null;
  }

  /// Projects this rich record onto the app's [Contact] model, keeping the
  /// extra fidelity that [Contact] can hold (photo thumbnail, birthday) while
  /// flattening the rest to its primary values.
  Contact toAppContact() {
    final org = primaryOrganization;
    final workplace = [
      org?.company ?? '',
      org?.title ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Contact(
      // Temporary client id; the backend assigns the real id on create.
      id: 'import-$sourceId',
      firstName: first,
      lastName: last,
      workplace: workplace,
      homeAddress: primaryAddress?.formattedOneLine ?? '',
      phone: primaryPhone,
      email: primaryEmail,
      notes: notes.where((n) => n.trim().isNotEmpty).join('\n'),
      tags: const ['Imported'],
      locationMet: '',
      dateMet: null,
      connections: const [],
      photoThumbnail: photo?.thumbnail ?? photo?.fullSize,
      birthday: birthday?.toDateTime(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'displayName': displayName,
        'first': first,
        'middle': middle,
        'last': last,
        'prefix': prefix,
        'suffix': suffix,
        'nickname': nickname,
        'phoneticFirst': phoneticFirst,
        'phoneticMiddle': phoneticMiddle,
        'phoneticLast': phoneticLast,
        'photo': photo?.toJson(),
        'phones': phones.map((e) => e.toJson()).toList(),
        'emails': emails.map((e) => e.toJson()).toList(),
        'addresses': addresses.map((e) => e.toJson()).toList(),
        'organizations': organizations.map((e) => e.toJson()).toList(),
        'websites': websites.map((e) => e.toJson()).toList(),
        'socialMedias': socialMedias.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'relations': relations.map((e) => e.toJson()).toList(),
        'notes': notes,
      };

  factory ImportedContact.fromJson(Map<String, dynamic> json) {
    List<LabeledValue> labeled(String key) =>
        ((json[key] as List?) ?? const [])
            .map((e) => LabeledValue.fromJson(e as Map<String, dynamic>))
            .toList();
    return ImportedContact(
      sourceId: json['sourceId'] as String,
      displayName: (json['displayName'] as String?) ?? '',
      first: (json['first'] as String?) ?? '',
      middle: (json['middle'] as String?) ?? '',
      last: (json['last'] as String?) ?? '',
      prefix: (json['prefix'] as String?) ?? '',
      suffix: (json['suffix'] as String?) ?? '',
      nickname: (json['nickname'] as String?) ?? '',
      phoneticFirst: (json['phoneticFirst'] as String?) ?? '',
      phoneticMiddle: (json['phoneticMiddle'] as String?) ?? '',
      phoneticLast: (json['phoneticLast'] as String?) ?? '',
      photo: json['photo'] != null
          ? ContactPhoto.fromJson(json['photo'] as Map<String, dynamic>)
          : null,
      phones: labeled('phones'),
      emails: labeled('emails'),
      addresses: ((json['addresses'] as List?) ?? const [])
          .map((e) => PostalAddress.fromJson(e as Map<String, dynamic>))
          .toList(),
      organizations: ((json['organizations'] as List?) ?? const [])
          .map((e) => ContactOrganization.fromJson(e as Map<String, dynamic>))
          .toList(),
      websites: labeled('websites'),
      socialMedias: labeled('socialMedias'),
      events: ((json['events'] as List?) ?? const [])
          .map((e) => ContactEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      relations: labeled('relations'),
      notes: List<String>.from(json['notes'] ?? const []),
    );
  }
}

/// A value (phone number, email, URL, …) plus its address-book label
/// (e.g. "mobile", "home", "work").
class LabeledValue {
  final String value;
  final String label;

  const LabeledValue({required this.value, this.label = ''});

  Map<String, dynamic> toJson() => {'value': value, 'label': label};

  factory LabeledValue.fromJson(Map<String, dynamic> json) => LabeledValue(
        value: (json['value'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
      );
}

/// A structured postal address.
class PostalAddress {
  final String formatted;
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String label;

  const PostalAddress({
    this.formatted = '',
    this.street = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.country = '',
    this.label = '',
  });

  /// A single-line rendering, preferring the OS-provided formatted string.
  String get formattedOneLine {
    if (formatted.isNotEmpty) return formatted.replaceAll('\n', ', ');
    return [street, city, state, postalCode, country]
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  Map<String, dynamic> toJson() => {
        'formatted': formatted,
        'street': street,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        'country': country,
        'label': label,
      };

  factory PostalAddress.fromJson(Map<String, dynamic> json) => PostalAddress(
        formatted: (json['formatted'] as String?) ?? '',
        street: (json['street'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        state: (json['state'] as String?) ?? '',
        postalCode: (json['postalCode'] as String?) ?? '',
        country: (json['country'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
      );
}

/// An employer / organization affiliation.
class ContactOrganization {
  final String company;
  final String title;
  final String department;
  final String jobDescription;

  const ContactOrganization({
    this.company = '',
    this.title = '',
    this.department = '',
    this.jobDescription = '',
  });

  Map<String, dynamic> toJson() => {
        'company': company,
        'title': title,
        'department': department,
        'jobDescription': jobDescription,
      };

  factory ContactOrganization.fromJson(Map<String, dynamic> json) =>
      ContactOrganization(
        company: (json['company'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        department: (json['department'] as String?) ?? '',
        jobDescription: (json['jobDescription'] as String?) ?? '',
      );
}

/// A dated event such as a birthday or anniversary. [year] is nullable because
/// many contacts record a birthday without a year.
class ContactEvent {
  final int? year;
  final int month;
  final int day;
  final String label;

  const ContactEvent({
    this.year,
    required this.month,
    required this.day,
    this.label = '',
  });

  bool get isBirthday => label.toLowerCase() == 'birthday';

  /// Resolves to a [DateTime]; falls back to a sentinel year (1900) when the
  /// contact stored no year so the month/day are still usable.
  DateTime toDateTime() => DateTime(year ?? 1900, month, day);

  Map<String, dynamic> toJson() => {
        'year': year,
        'month': month,
        'day': day,
        'label': label,
      };

  factory ContactEvent.fromJson(Map<String, dynamic> json) => ContactEvent(
        year: (json['year'] as num?)?.toInt(),
        month: (json['month'] as num).toInt(),
        day: (json['day'] as num).toInt(),
        label: (json['label'] as String?) ?? '',
      );
}

/// A contact photo, holding the small thumbnail and/or the full-resolution
/// image as raw bytes.
class ContactPhoto {
  final Uint8List? thumbnail;
  final Uint8List? fullSize;

  const ContactPhoto({this.thumbnail, this.fullSize});

  Map<String, dynamic> toJson() => {
        if (thumbnail != null) 'thumbnail': base64Encode(thumbnail!),
        if (fullSize != null) 'fullSize': base64Encode(fullSize!),
      };

  factory ContactPhoto.fromJson(Map<String, dynamic> json) => ContactPhoto(
        thumbnail: json['thumbnail'] != null
            ? base64Decode(json['thumbnail'] as String)
            : null,
        fullSize: json['fullSize'] != null
            ? base64Decode(json['fullSize'] as String)
            : null,
      );
}
