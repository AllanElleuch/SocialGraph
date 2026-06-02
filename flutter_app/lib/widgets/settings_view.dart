import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Version of the bundled legal documents (privacy policy + terms of use).
/// Keep this in sync with the `version:` front-matter in
/// `assets/legal/*.md` and with the deployed Cloudflare Pages site.
const String legalDocsVersion = '1.0.0';

/// Effective date of the current legal documents, shown in Settings.
const String legalDocsEffective = '2 June 2026';

/// Public, hosted copies of the legal documents (Cloudflare Pages).
const String privacyPolicyUrl = 'https://codelio-legal.pages.dev/privacy-policy.html';
const String termsOfUseUrl = 'https://codelio-legal.pages.dev/terms-of-use.html';

/// Support / privacy contact address.
const String supportEmail = 'contact@codelio.fr';

class _Palette {
  static const Color background = Color(0xFF0A0A0A);
  static const Color accent = Color(0xFF818CF8);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF9CA3AF);
}

/// A full-screen Settings page exposing the App's legal documents and support
/// contact. Documents are bundled as assets so they are available offline, and
/// also link to their hosted Cloudflare Pages copies.
class SettingsView extends StatelessWidget {
  /// Opens the local backup export dialog. Null hides the entry.
  final VoidCallback? onExportBackup;

  /// Opens the local backup import dialog. Null hides the entry.
  final VoidCallback? onImportBackup;

  /// Opens the cloud backups manager. Null hides the entry (cloud disabled).
  final VoidCallback? onCloudBackups;

  /// Starts the sign-in flow. Null hides the Account section (cloud disabled).
  final VoidCallback? onSignIn;

  /// Signs the user out. Null hides the Account section (cloud disabled).
  final VoidCallback? onSignOut;

  /// Whether a user is currently signed in (drives the Account tile label).
  final bool isSignedIn;

  const SettingsView({
    super.key,
    this.onExportBackup,
    this.onImportBackup,
    this.onCloudBackups,
    this.onSignIn,
    this.onSignOut,
    this.isSignedIn = false,
  });

  /// Pushes the Settings page as a full-screen route.
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onExportBackup,
    VoidCallback? onImportBackup,
    VoidCallback? onCloudBackups,
    VoidCallback? onSignIn,
    VoidCallback? onSignOut,
    bool isSignedIn = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsView(
          onExportBackup: onExportBackup,
          onImportBackup: onImportBackup,
          onCloudBackups: onCloudBackups,
          onSignIn: onSignIn,
          onSignOut: onSignOut,
          isSignedIn: isSignedIn,
        ),
      ),
    );
  }

  bool get _hasBackups =>
      onCloudBackups != null || onExportBackup != null || onImportBackup != null;

  bool get _hasAccount => onSignIn != null || onSignOut != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      appBar: AppBar(
        backgroundColor: _Palette.background,
        foregroundColor: _Palette.textPrimary,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          if (_hasAccount) ...[
            const _SectionHeader('Account'),
            _SettingsTile(
              icon: isSignedIn ? Icons.logout : Icons.login,
              title: isSignedIn ? 'Sign out' : 'Sign in to sync',
              subtitle: isSignedIn
                  ? 'Stop syncing on this device'
                  : 'Sync your contacts across devices',
              onTap: () {
                // Return to the app first so it reflects the new auth state,
                // then run the action (which may push its own screen/snackbar).
                Navigator.of(context).pop();
                (isSignedIn ? onSignOut : onSignIn)?.call();
              },
            ),
          ],
          if (_hasBackups) ...[
            const _SectionHeader('Data & Backups'),
            if (onCloudBackups != null)
              _SettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Cloud backups',
                subtitle: 'Save and restore from the cloud',
                onTap: onCloudBackups!,
              ),
            if (onExportBackup != null)
              _SettingsTile(
                icon: Icons.upload_file_outlined,
                title: 'Export backup',
                subtitle: 'Copy your contacts as JSON',
                onTap: onExportBackup!,
              ),
            if (onImportBackup != null)
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Import backup',
                subtitle: 'Restore contacts from JSON',
                onTap: onImportBackup!,
              ),
          ],
          const _SectionHeader('Legal'),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => LegalDocView.show(
              context,
              title: 'Privacy Policy',
              assetPath: 'assets/legal/privacy-policy.md',
              onlineUrl: privacyPolicyUrl,
            ),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Use',
            onTap: () => LegalDocView.show(
              context,
              title: 'Terms of Use',
              assetPath: 'assets/legal/terms-of-use.md',
              onlineUrl: termsOfUseUrl,
            ),
          ),
          const _SectionHeader('Support'),
          _SettingsTile(
            icon: Icons.mail_outline,
            title: 'Contact us',
            subtitle: supportEmail,
            onTap: () => _contactSupport(context),
          ),
          const SizedBox(height: 24),
          const _SettingsFooter(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Footer with the copyright line and the app version/build number.
class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter();

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Center(
      child: Column(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              // pubspec `1.0.0+2` → version "1.0.0", build number / build
              // offset "2". e.g. "Version 1.0.0 · Build 2". Falls back to the
              // legal docs version when package info is unavailable (tests).
              final label = info != null
                  ? 'Version ${info.version} · Build ${info.buildNumber}'
                  : 'Version $legalDocsVersion';
              return Text(
                label,
                style: const TextStyle(color: _Palette.textMuted, fontSize: 12),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            '© $year Codelio. All rights reserved.',
            style: const TextStyle(color: _Palette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _Palette.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _Palette.accent),
      title: Text(title, style: const TextStyle(color: _Palette.textPrimary)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: const TextStyle(color: _Palette.textMuted, fontSize: 12)),
      trailing:
          const Icon(Icons.chevron_right, color: _Palette.textMuted, size: 20),
      onTap: onTap,
    );
  }
}

Future<void> _launch(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Opens the user's mail app composing to the support address. Tries to launch
/// directly (don't gate on `canLaunchUrl`, which returns false on devices with
/// no configured mail client) and, if that fails, copies the address to the
/// clipboard with a clear message so the tap is never a silent no-op.
Future<void> _contactSupport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: 'subject=${Uri.encodeComponent('Social Graph support')}',
  );

  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }

  if (!opened) {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No mail app found. Address copied: $supportEmail'),
      ),
    );
  }
}

/// Reads a bundled markdown document and renders it in a scrollable, dark-theme
/// view. Provides a button to open the hosted online copy.
class LegalDocView extends StatelessWidget {
  final String title;
  final String assetPath;
  final String onlineUrl;

  const LegalDocView({
    super.key,
    required this.title,
    required this.assetPath,
    required this.onlineUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String assetPath,
    required String onlineUrl,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocView(
          title: title,
          assetPath: assetPath,
          onlineUrl: onlineUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.background,
      appBar: AppBar(
        backgroundColor: _Palette.background,
        foregroundColor: _Palette.textPrimary,
        elevation: 0,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'View online',
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () => _launch(Uri.parse(onlineUrl)),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Could not load document.',
                  style: TextStyle(color: _Palette.textMuted)),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: renderMarkdown(stripFrontMatter(snapshot.data!)),
            ),
          );
        },
      ),
    );
  }
}

/// Removes a leading `--- ... ---` YAML front-matter block, if present.
String stripFrontMatter(String source) {
  final text = source.replaceAll('\r\n', '\n');
  if (!text.startsWith('---\n')) return text.trim();
  final end = text.indexOf('\n---', 4);
  if (end == -1) return text.trim();
  final after = text.indexOf('\n', end + 1);
  return after == -1 ? '' : text.substring(after + 1).trim();
}

/// Renders a small, controlled subset of markdown (headings, paragraphs,
/// unordered lists, bold) into a list of widgets. Intended for our own legal
/// documents, not arbitrary markdown.
List<Widget> renderMarkdown(String markdown) {
  final widgets = <Widget>[];
  final buffer = <String>[];
  // The kind of block currently accumulating in [buffer]: 'p', 'li', or null.
  String? blockKind;

  void flush() {
    if (buffer.isEmpty) return;
    final text = buffer.join(' ');
    widgets.add(blockKind == 'li' ? _bullet(text) : _paragraph(text));
    buffer.clear();
    blockKind = null;
  }

  for (final rawLine in markdown.split('\n')) {
    final line = rawLine.trimRight();
    final indentedContinuation = RegExp(r'^\s+\S').hasMatch(line);
    if (line.isEmpty) {
      flush();
      widgets.add(const SizedBox(height: 12));
    } else if (blockKind == 'li' && indentedContinuation) {
      buffer.add(line.trim()); // continuation of the current bullet
    } else if (line.startsWith('### ')) {
      flush();
      widgets.add(_heading(line.substring(4), 16));
    } else if (line.startsWith('## ')) {
      flush();
      widgets.add(_heading(line.substring(3), 18));
    } else if (line.startsWith('# ')) {
      flush();
      widgets.add(_heading(line.substring(2), 24));
    } else if (line.startsWith('- ')) {
      flush();
      blockKind = 'li';
      buffer.add(line.substring(2));
    } else {
      if (blockKind != 'p') flush();
      blockKind = 'p';
      buffer.add(line);
    }
  }
  flush();
  return widgets;
}

Widget _heading(String text, double size) {
  return Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Text(
      _stripInline(text),
      style: TextStyle(
        color: _Palette.textPrimary,
        fontSize: size,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _paragraph(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      _inlineSpans(text),
      style: const TextStyle(
          color: _Palette.textPrimary, fontSize: 14, height: 1.5),
    ),
  );
}

Widget _bullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ',
            style: TextStyle(color: _Palette.accent, fontSize: 14)),
        Expanded(
          child: Text.rich(
            _inlineSpans(text),
            style: const TextStyle(
                color: _Palette.textPrimary, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

/// Splits a line into spans, applying bold styling to `**text**` segments.
TextSpan _inlineSpans(String text) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var index = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(TextSpan(text: text.substring(index, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index)));
  }
  return TextSpan(children: spans);
}

/// Strips inline markdown markers for use in plain (heading) text.
String _stripInline(String text) =>
    text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
