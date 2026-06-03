import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as device;
import '../models/contact.dart';
import '../models/imported_contact.dart';

/// Outcome of a device-contacts import attempt.
enum ImportStatus {
  /// Permission granted (fully or limited) and contacts were read.
  success,

  /// User denied the permission but can be asked again.
  denied,

  /// Permission is permanently denied / restricted; user must enable it in
  /// Settings.
  permanentlyDenied,
}

class ImportResult {
  final ImportStatus status;

  /// Contacts mapped onto the app model (for display/save).
  final List<Contact> contacts;

  /// The full-fidelity device records behind [contacts], index-aligned, kept in
  /// case callers want richer data (all phones/emails, photo bytes, events…).
  final List<ImportedContact> imported;

  const ImportResult(
    this.status, [
    this.contacts = const [],
    this.imported = const [],
  ]);
}

/// Reads contacts from the device address book (iOS/Android) and maps them to
/// the app's [Contact] model — preserving the photo and all linked metadata.
class ContactsImportService {
  /// Properties requested from the OS. We pull *everything* the contact links
  /// to, including the photo thumbnail, so nothing is silently dropped.
  ///
  /// Notes are intentionally excluded by default: on iOS they require the
  /// `com.apple.developer.contacts.notes` entitlement (granted only by special
  /// Apple request) plus `FlutterContacts.config.enableIosNotes = true`. Enable
  /// [withNotes] once that entitlement is in place.
  static const Set<device.ContactProperty> _properties = {
    device.ContactProperty.name,
    device.ContactProperty.phone,
    device.ContactProperty.email,
    device.ContactProperty.address,
    device.ContactProperty.organization,
    device.ContactProperty.website,
    device.ContactProperty.socialMedia,
    device.ContactProperty.event,
    device.ContactProperty.relation,
    device.ContactProperty.photoThumbnail,
  };

  final bool withNotes;

  ContactsImportService({this.withNotes = false});

  /// Requests read permission and returns the device contacts mapped to the
  /// app model. The [status] tells the caller how to react if access was not
  /// granted.
  Future<ImportResult> importFromDevice() async {
    final status = await device.FlutterContacts.permissions
        .request(device.PermissionType.read);

    switch (status) {
      case device.PermissionStatus.granted:
      case device.PermissionStatus.limited:
        break;
      case device.PermissionStatus.restricted:
      case device.PermissionStatus.permanentlyDenied:
        return const ImportResult(ImportStatus.permanentlyDenied);
      case device.PermissionStatus.denied:
      case device.PermissionStatus.notDetermined:
        return const ImportResult(ImportStatus.denied);
    }

    final properties = withNotes
        ? {..._properties, device.ContactProperty.note}
        : _properties;

    final deviceContacts =
        await device.FlutterContacts.getAll(properties: properties);

    final imported = deviceContacts.map(_toImported).toList();
    final platform = _platformLabel();
    final importedAt = DateTime.now();
    final mapped = imported
        .map((i) => i.toAppContact(platform: platform, importedAt: importedAt))
        .where((c) => c.displayName.isNotEmpty)
        .toList();

    return ImportResult(ImportStatus.success, mapped, imported);
  }

  /// A human-readable label for the current platform, recorded as import
  /// provenance (e.g. "iOS", "Android").
  String _platformLabel() {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Opens the system settings so the user can grant a permanently-denied
  /// permission.
  Future<void> openSettings() =>
      device.FlutterContacts.permissions.openSettings();

  /// Maps a plugin [device.Contact] onto the plugin-agnostic [ImportedContact],
  /// preserving every linked phone/email/address/org/site/event/relation and
  /// the photo bytes.
  ImportedContact _toImported(device.Contact c) {
    final photo = c.photo;
    return ImportedContact(
      sourceId: c.id ?? '',
      displayName: c.displayName ?? '',
      first: c.name?.first ?? '',
      middle: c.name?.middle ?? '',
      last: c.name?.last ?? '',
      prefix: c.name?.prefix ?? '',
      suffix: c.name?.suffix ?? '',
      nickname: c.name?.nickname ?? '',
      phoneticFirst: c.name?.phoneticFirst ?? '',
      phoneticMiddle: c.name?.phoneticMiddle ?? '',
      phoneticLast: c.name?.phoneticLast ?? '',
      photo: (photo != null &&
              (photo.thumbnail != null || photo.fullSize != null))
          ? ContactPhoto(thumbnail: photo.thumbnail, fullSize: photo.fullSize)
          : null,
      phones: [
        for (final p in c.phones)
          LabeledValue(value: p.number, label: _labelText(p.label)),
      ],
      emails: [
        for (final e in c.emails)
          LabeledValue(value: e.address, label: _labelText(e.label)),
      ],
      addresses: [
        for (final a in c.addresses)
          PostalAddress(
            formatted: a.formatted ?? '',
            street: a.street ?? '',
            city: a.city ?? '',
            state: a.state ?? '',
            postalCode: a.postalCode ?? '',
            country: a.country ?? '',
            label: _labelText(a.label),
          ),
      ],
      organizations: [
        for (final o in c.organizations)
          ContactOrganization(
            company: o.name ?? '',
            title: o.jobTitle ?? '',
            department: o.departmentName ?? '',
            jobDescription: o.jobDescription ?? '',
          ),
      ],
      websites: [
        for (final w in c.websites)
          LabeledValue(value: w.url, label: _labelText(w.label)),
      ],
      socialMedias: [
        for (final s in c.socialMedias)
          LabeledValue(value: s.username, label: _labelText(s.label)),
      ],
      events: [
        for (final e in c.events)
          ContactEvent(
            year: e.year,
            month: e.month,
            day: e.day,
            label: _labelText(e.label),
          ),
      ],
      relations: [
        for (final r in c.relations)
          LabeledValue(value: r.name, label: _labelText(r.label)),
      ],
      notes: [
        for (final n in c.notes)
          if (n.note.trim().isNotEmpty) n.note,
      ],
    );
  }

  /// Renders a plugin [device.Label] to a display string: the user's custom
  /// text when present, otherwise the enum name (e.g. "mobile", "home").
  String _labelText<T extends Enum>(device.Label<T> label) {
    final custom = label.customLabel;
    if (custom != null && custom.isNotEmpty) return custom;
    return label.label.name;
  }
}
