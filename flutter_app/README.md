# Social Graph (Flutter)

Flutter client for the Contextual Contacts network explorer. It renders your
contacts as an interactive graph, a map, and a timeline, and reads/writes them
through the Express backend in the repo root (`server.ts`).

## Running

From the repo root (npm scripts wrap the Flutter CLI):

```bash
npm run flutter:web         # run in Chrome (web)
npm run flutter:web:build   # production web build -> flutter_app/build/web
npm run flutter:ios         # run on the iOS simulator
npm run flutter:ios:build   # simulator build (no signing)
```

Or directly inside `flutter_app/`:

```bash
flutter pub get
flutter run -d chrome       # web
flutter run -d ios          # iOS simulator
```

The app talks to the backend at `http://localhost:3000` (`ContactService`). Start
it with `npm run dev` from the repo root. If the server is unreachable the app
falls back to bundled seed data and keeps new contacts in local state.

## Views

Switch views from the bottom bar (tap the ℹ️ button in the header for an
in-app description):

- **Mutuals** — clusters contacts by their shared connections.
- **Location** — places contacts on a map by where you met / where they live.
- **Timeline** — orders contacts chronologically by the date you met.

## Importing contacts from the phone (iOS / Android)

Tap the **contacts icon** (📇) in the header to import the device address book.
The button is hidden on web, where the device contacts API is unavailable.

### What happens

1. The system permission prompt is shown the first time
   (`ContactsImportService.importFromDevice`).
2. On grant (including iOS 18 *limited* access), device contacts are read with
   `FlutterContacts.getAll`, requesting only name, email, organization, and
   address properties.
3. Each device contact is mapped to the app `Contact` model:

   | App field     | Source                                   |
   | ------------- | ---------------------------------------- |
   | `firstName`   | `name.first`                             |
   | `lastName`    | `name.last`                              |
   | `workplace`   | organization name · job title            |
   | `homeAddress` | formatted / structured postal address    |
   | `tags`        | `['Imported']`                           |
   | `dateMet`     | import time                              |

4. Contacts whose display name already exists are skipped (de-dupe).
5. Remaining contacts are saved via the backend; if it is unreachable they are
   added to local state instead. A snackbar reports the result.

If permission is **permanently denied / restricted**, the snackbar offers a
**Settings** action (`FlutterContacts.permissions.openSettings`).

### iOS setup (already configured)

- `ios/Runner/Info.plist` declares the required usage string:

  ```xml
  <key>NSContactsUsageDescription</key>
  <string>Social Graph needs access to your contacts so you can import them into your network.</string>
  ```

- Minimum deployment target is **iOS 13.0** (`ios/Podfile` and the Xcode
  project), which `flutter_contacts` requires. `pod install` runs automatically
  on the next `flutter run`.

> Note: the iOS Simulator's address book is empty by default. Add a contact in
> the Simulator's Contacts app (or import a vCard) to see import results, or run
> on a physical device.

## Key files

- `lib/main.dart` — app shell, header, view switching, import wiring.
- `lib/services/contact_service.dart` — backend CRUD + seed-data fallback.
- `lib/services/contacts_import_service.dart` — device-contacts permission,
  fetch, and mapping to the app model.
- `lib/widgets/` — graph, map, timeline, contact card/form, controls.
- `lib/models/contact.dart` — the `Contact` model and `PivotType`.
