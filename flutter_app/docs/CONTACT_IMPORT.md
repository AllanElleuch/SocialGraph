# Contact Import (iOS / Android)

How Social Graph imports device contacts, what data it captures, and the
platform requirements. Importing now preserves **the photo and all metadata
linked to a contact**, not just name + first phone/email.

- Source: device address book via the [`flutter_contacts`](https://pub.dev/packages/flutter_contacts) plugin (v2.1.0).
- Entry points: `lib/services/contacts_import_service.dart`,
  `lib/models/imported_contact.dart`, `lib/models/contact.dart`.

## Data model

Two models are involved:

| Model | Purpose |
|-------|---------|
| `ImportedContact` (`models/imported_contact.dart`) | **High-fidelity** snapshot of a device entry. Keeps *every* linked value — all phones/emails/addresses, organizations, websites, social profiles, events, relations, notes, and the photo bytes. Plugin-agnostic, JSON-serializable. |
| `Contact` (`models/contact.dart`) | The app's working model. Holds the primary phone/email/address plus the newly-added `photoThumbnail` (bytes) and `birthday`. |

`ImportedContact.toAppContact()` projects the rich record onto `Contact`:
primary values are flattened, while the **photo thumbnail and birthday are
carried through**.

### `ImportedContact` structure

```
ImportedContact
├─ sourceId, displayName
├─ name: first, middle, last, prefix, suffix, nickname, phonetic{First,Middle,Last}
├─ photo: ContactPhoto { thumbnail: bytes, fullSize: bytes }
├─ phones[]        : LabeledValue { value, label }      // mobile/home/work/custom
├─ emails[]        : LabeledValue
├─ addresses[]     : PostalAddress { formatted, street, city, state, postalCode, country, label }
├─ organizations[] : ContactOrganization { company, title, department, jobDescription }
├─ websites[]      : LabeledValue
├─ socialMedias[]  : LabeledValue
├─ events[]        : ContactEvent { year?, month, day, label }   // birthday/anniversary
├─ relations[]     : LabeledValue
└─ notes[]         : String                              // iOS: entitlement required (see below)
```

## Field mapping (device → app `Contact`)

| Device (`flutter_contacts`) | `ImportedContact` | App `Contact` |
|---|---|---|
| `name.first` / `name.last` | `first` / `last` | `firstName` / `lastName` |
| `name.middle/prefix/suffix/nickname/phonetic*` | kept | — (available via `ImportedContact`) |
| `photo.thumbnail` / `photo.fullSize` | `photo` | `photoThumbnail` (thumbnail preferred) |
| `phones[]` (all) | `phones[]` | `phone` (first only) |
| `emails[]` (all) | `emails[]` | `email` (first only) |
| `addresses[]` (all) | `addresses[]` | `homeAddress` (first, one-line) |
| `organizations[0].name/jobTitle` | `organizations[]` | `workplace` = `name · jobTitle` |
| `events[]` (birthday) | `events[]` | `birthday` (first birthday) |
| `websites/socialMedias/relations[]` | kept | — (available via `ImportedContact`) |
| `notes[]` | `notes[]` | `notes` (joined) |
| — (OS gives no "met" date) | — | `dateMet = null`; tags `['Imported']` |

The full `ImportedContact` is returned alongside the mapped `Contact` in
`ImportResult.imported` (index-aligned), so additional metadata can be surfaced
in the UI later without re-reading the address book.

## Photos

- Requested with `ContactProperty.photoThumbnail` (small, fast — good for an
  avatar list). Swap to / add `ContactProperty.photoFullRes` for full-resolution.
- Stored on `Contact.photoThumbnail` as raw bytes, persisted as **base64** in
  JSON. `Contact.hasPhoto` gates display. The contact card renders it via
  `MemoryImage`.
- Per the plugin docs: when **reading**, the OS auto-generates thumbnails from
  full-size images; when **writing**, set `Photo(fullSize: bytes)` and the
  platform derives the thumbnail.

> Storage note: thumbnails are a few KB each. They are persisted locally and
> included in cloud sync payloads. If a very large address book makes payloads
> heavy, switch `photoThumbnail` to load-on-demand instead of persisting.

## iOS requirements

### Permission (required)

`ios/Runner/Info.plist` must declare the contacts usage string (already present):

```xml
<key>NSContactsUsageDescription</key>
<string>Social Graph needs access to your contacts so you can import them into your network.</string>
```

### Notes (optional, gated)

Reading a contact's **notes** on iOS needs Apple's special-access entitlement:

1. Add the entitlement `com.apple.developer.contacts.notes` to the app
   (requires approval via an Apple request form).
2. Enable it at runtime: `FlutterContacts.config.enableIosNotes = true`.
3. Construct the service with `ContactsImportService(withNotes: true)` so
   `ContactProperty.note` is requested.

Until the entitlement is granted, notes import is disabled by default and the
rest of the import works normally.

## Usage

```dart
final result = await ContactsImportService().importFromDevice();
switch (result.status) {
  case ImportStatus.success:
    final contacts = result.contacts;   // mapped app Contacts (with photo + birthday)
    final rich = result.imported;        // full-fidelity records, index-aligned
  case ImportStatus.denied:              // ask again
  case ImportStatus.permanentlyDenied:   // deep-link to Settings
}
```

## References

- flutter_contacts on pub.dev: https://pub.dev/packages/flutter_contacts
- Apple — Requesting access to protected resources:
  https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/requesting_access_to_protected_resources
- Apple — Contacts notes entitlement: `com.apple.developer.contacts.notes`

## Tests

- `test/imported_contact_test.dart` — fidelity, `toAppContact()` mapping, JSON
  round-trip (incl. photo bytes), and `Contact` photo/birthday serialization.
