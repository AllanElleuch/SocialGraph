<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://ai.google.dev/static/site-assets/images/share-ais-513315318.png" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/442a54f5-08f8-45fd-b7aa-6be14621d843

## Run Locally

**Prerequisites:**  Node.js


1. Install dependencies:
   `npm install`
2. Set the `GEMINI_API_KEY` in [.env.local](.env.local) to your Gemini API key
3. Run the app:
   `npm run dev`

## App Store Connect / iOS identifiers

Recorded here so they never drift again — a casing mismatch once broke App Store
uploads (Xcode tried to register a *new* bundle ID because the project used
lowercase while App Store Connect used capital **G**).

| Field | Value | Notes |
| --- | --- | --- |
| **Bundle ID** | `com.codelio.socialGraph` | ⚠️ capital **G** — case-sensitive and **immutable** in App Store Connect |
| **SKU** | `com.codelio.socialgraph` | internal-only identifier; may differ from the Bundle ID |
| **Apple Team ID** | `7VKGAZ92DM` | |
| **Firebase project** | `socialgraph-69110` | |

The Bundle ID must match **exactly** (same casing) in all of:

- `flutter_app/ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`)
- `flutter_app/ios/Runner/GoogleService-Info.plist` (`BUNDLE_ID`)
- `flutter_app/lib/firebase_options.dart` (`iosBundleId`)

## Cloudflare

The project's public-facing static content is hosted on **Cloudflare Pages**.

| Resource | Cloudflare service | Project → URL |
| --- | --- | --- |
| Public legal site (Privacy Policy & Terms of Use) | Pages | `codelio-legal` → https://codelio-legal.pages.dev |

The site is generated from the **same** Markdown the Flutter app bundles, so the
in-app and web copies never drift. Build and deploy with the Wrangler CLI:

```bash
node legal/build.mjs                                              # build → legal/dist/
npx wrangler pages deploy legal/dist --project-name codelio-legal # deploy
```

First-time setup: `npx wrangler login`, then create the project once with
`npx wrangler pages project create codelio-legal`. See
[Legal documents → Public website](#public-website-cloudflare-pages) for the
full versioning workflow.

> **What is _not_ on Cloudflare:** the app's data backend is **Firebase** —
> Firestore for per-user cloud sync and backups, Firebase Auth for sign-in.
> There is no Cloudflare Worker; an earlier local Express prototype was retired
> in favour of local-first storage + Firestore.

## Legal documents (Privacy Policy & Terms of Use)

The legal documents are versioned Markdown files that serve as the **single
source of truth** for both the Flutter app and the public website:

| File | Purpose |
| --- | --- |
| [`flutter_app/assets/legal/privacy-policy.md`](flutter_app/assets/legal/privacy-policy.md) | Privacy Policy |
| [`flutter_app/assets/legal/terms-of-use.md`](flutter_app/assets/legal/terms-of-use.md) | Terms of Use |

**Contact:** `contact@codelio.fr`

### Versioning

Each document carries a `version` and `effective` date in its YAML front
matter (currently **v1.0.0**, effective **2 June 2026**). When you change a
document:

1. Bump `version` (semver) and update `effective` in the Markdown front matter.
2. Update `legalDocsVersion` / `legalDocsEffective` in
   [`flutter_app/lib/widgets/settings_view.dart`](flutter_app/lib/widgets/settings_view.dart)
   to match.
3. Rebuild and redeploy the website (below).

### In-app display

The Flutter app bundles both files as assets and renders them in
**Settings → Legal** (`SettingsView` / `LegalDocView` in
`lib/widgets/settings_view.dart`), so they are available offline. Each document
also links out to its hosted copy.

### Public website (Cloudflare Pages)

A zero-dependency build script renders the same Markdown into a styled static
site:

```bash
# Generate legal/dist/{index,privacy-policy,terms-of-use}.html from the Markdown
node legal/build.mjs

# Deploy to Cloudflare Pages (project: codelio-legal)
npx wrangler pages deploy legal/dist --project-name codelio-legal
```

This publishes:

- `https://codelio-legal.pages.dev/privacy-policy.html`
- `https://codelio-legal.pages.dev/terms-of-use.html`

> First-time setup: run `npx wrangler login`, then create the Pages project
> once with `npx wrangler pages project create codelio-legal`. The generated
> `legal/dist/` directory is build output and does not need to be committed.

Update the `privacyPolicyUrl` / `termsOfUseUrl` constants in
`settings_view.dart` if you deploy to a different Pages domain (e.g. a custom
domain).
