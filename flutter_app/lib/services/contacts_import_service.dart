import 'package:flutter_contacts/flutter_contacts.dart' as device;
import '../models/contact.dart';

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
  final List<Contact> contacts;

  const ImportResult(this.status, [this.contacts = const []]);
}

/// Reads contacts from the device address book (iOS/Android) and maps them to
/// the app's [Contact] model.
class ContactsImportService {
  /// Requests read permission and returns the device contacts mapped to the
  /// app model. The [status] tells the caller how to react if access was not
  /// granted.
  Future<ImportResult> importFromDevice() async {
    final status =
        await device.FlutterContacts.permissions.request(device.PermissionType.read);

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

    final deviceContacts = await device.FlutterContacts.getAll(
      properties: {
        device.ContactProperty.name,
        device.ContactProperty.phone,
        device.ContactProperty.email,
        device.ContactProperty.address,
        device.ContactProperty.organization,
      },
    );

    final mapped = deviceContacts
        .map(_mapToContact)
        .where((c) => c.displayName.isNotEmpty)
        .toList();

    return ImportResult(ImportStatus.success, mapped);
  }

  /// Opens the system settings so the user can grant a permanently-denied
  /// permission.
  Future<void> openSettings() => device.FlutterContacts.permissions.openSettings();

  Contact _mapToContact(device.Contact c) {
    final org = c.organizations.isNotEmpty ? c.organizations.first : null;
    final workplace = [
      org?.name ?? '',
      org?.jobTitle ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');

    final address = c.addresses.isNotEmpty ? _formatAddress(c.addresses.first) : '';
    final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
    final email = c.emails.isNotEmpty ? c.emails.first.address : '';

    return Contact(
      // Temporary client id; the backend assigns the real id on create.
      id: 'import-${c.id}',
      firstName: c.name?.first ?? '',
      lastName: c.name?.last ?? '',
      workplace: workplace,
      homeAddress: address,
      phone: phone,
      email: email,
      tags: const ['Imported'],
      locationMet: '',
      dateMet: DateTime.now(),
      connections: const [],
    );
  }

  String _formatAddress(device.Address a) {
    final formatted = a.formatted ?? '';
    if (formatted.isNotEmpty) return formatted.replaceAll('\n', ', ');
    return [a.street, a.city, a.state, a.postalCode, a.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
  }
}
