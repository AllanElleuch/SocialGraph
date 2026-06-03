import 'dart:math' as math;

import 'package:flutter_contacts/flutter_contacts.dart' as device;

import '../models/contact.dart';
import 'import_dedup.dart';

/// Outcome of an export-to-device attempt.
enum ExportStatus {
  /// Permission granted (fully or limited) and contacts were written.
  success,

  /// User denied the permission but can be asked again.
  denied,

  /// Permission is permanently denied / restricted; user must enable it in
  /// Settings.
  permanentlyDenied,
}

class ExportResult {
  final ExportStatus status;

  /// How many contacts were actually written to the device address book.
  final int exported;

  /// How many were skipped because an equivalent contact already exists on the
  /// device (matched by phone / email / name).
  final int skipped;

  const ExportResult(this.status, {this.exported = 0, this.skipped = 0});
}

/// Writes the app's contacts **into** the device address book (iOS/Android).
///
/// This is the inverse of [ContactsImportService], which only reads. The pure
/// pieces — [appContactToDevice] (model → plugin contact) and [plannedExports]
/// (which contacts to write after de-duping against the device) — are factored
/// out so they're unit-testable without platform channels.
class ContactsExportService {
  /// Insert in batches so a large export (e.g. 1500 contacts) reports progress
  /// without one giant, opaque platform call.
  final int batchSize;

  ContactsExportService({this.batchSize = 50});

  /// Requests write access and writes [contacts] not already on the device.
  ///
  /// [onProgress] is called as `(done, total)` after each batch so the UI can
  /// show a determinate progress bar. Never throws for permission issues — the
  /// [ExportResult.status] tells the caller how to react.
  Future<ExportResult> exportToDevice(
    List<Contact> contacts, {
    void Function(int done, int total)? onProgress,
  }) async {
    final status = await device.FlutterContacts.permissions.request(
      device.PermissionType.readWrite,
    );

    switch (status) {
      case device.PermissionStatus.granted:
      case device.PermissionStatus.limited:
        break;
      case device.PermissionStatus.restricted:
      case device.PermissionStatus.permanentlyDenied:
        return const ExportResult(ExportStatus.permanentlyDenied);
      case device.PermissionStatus.denied:
      case device.PermissionStatus.notDetermined:
        return const ExportResult(ExportStatus.denied);
    }

    // Read existing device contacts (names/phones/emails only) to skip ones
    // already present.
    final existing = await device.FlutterContacts.getAll(
      properties: const {
        device.ContactProperty.name,
        device.ContactProperty.phone,
        device.ContactProperty.email,
      },
    );
    final onDevice = existing.map(_deviceToMinimalApp).toList();
    final toExport = plannedExports(contacts, onDevice);

    final total = toExport.length;
    if (total == 0) {
      return ExportResult(
        ExportStatus.success,
        exported: 0,
        skipped: contacts.length,
      );
    }

    var done = 0;
    for (var i = 0; i < toExport.length; i += batchSize) {
      final end = math.min(i + batchSize, toExport.length);
      final batch = toExport.sublist(i, end);
      await device.FlutterContacts.createAll(
        batch.map(appContactToDevice).toList(),
      );
      done = end;
      onProgress?.call(done, total);
    }

    return ExportResult(
      ExportStatus.success,
      exported: total,
      skipped: contacts.length - total,
    );
  }

  /// Opens system settings so the user can grant a permanently-denied
  /// permission.
  Future<void> openSettings() =>
      device.FlutterContacts.permissions.openSettings();

  /// Minimal app [Contact] carrying just the fields [dedupeImportedContacts]
  /// matches on, built from a device contact.
  Contact _deviceToMinimalApp(device.Contact c) => Contact(
    id: c.id ?? '',
    firstName: (c.displayName?.isNotEmpty ?? false)
        ? c.displayName!
        : (c.name?.first ?? ''),
    lastName: '',
    tags: const [],
    connections: const [],
    locationMet: '',
    phone: c.phones.isNotEmpty ? c.phones.first.number : '',
    email: c.emails.isNotEmpty ? c.emails.first.address : '',
  );
}

/// The contacts from [ours] that should be written to the device — i.e. those
/// not already present on the device ([onDevice]) and not repeated within the
/// batch. Reuses the import de-dup (matching by device id / phone / email /
/// name), just in the opposite direction.
List<Contact> plannedExports(List<Contact> ours, List<Contact> onDevice) =>
    dedupeImportedContacts(onDevice, ours);

/// Maps an app [Contact] onto a plugin [device.Contact] for writing. Only the
/// fields the app stores are set; empty fields produce no entry. Pure.
device.Contact appContactToDevice(Contact c) {
  final phone = c.phone.trim();
  final email = c.email.trim();
  final workplace = c.workplace.trim();
  final address = c.homeAddress.trim();
  return device.Contact(
    name: device.Name(first: c.firstName, last: c.lastName),
    phones: [if (phone.isNotEmpty) device.Phone(number: phone)],
    emails: [if (email.isNotEmpty) device.Email(address: email)],
    organizations: [
      if (workplace.isNotEmpty) device.Organization(name: workplace),
    ],
    addresses: [if (address.isNotEmpty) device.Address(street: address)],
  );
}
