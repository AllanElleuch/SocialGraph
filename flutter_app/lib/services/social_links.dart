/// A social network the app can store a handle for and deep-link to.
///
/// Pure Dart (no Flutter imports) so it can be unit-tested and reused; the UI
/// maps [id] onto an icon. Handles are stored bare (no leading `@`, no URL) in
/// [Contact.socials], keyed by [id]; [profileUrl] reconstructs the public link.
class SocialPlatform {
  /// Stable key persisted in `Contact.socials` (e.g. `'instagram'`).
  final String id;

  /// Human-readable name shown in the UI (e.g. `'Instagram'`).
  final String label;

  /// Placeholder shown in the edit field (e.g. `'@username'`).
  final String hint;

  final String Function(String handle) _buildUrl;

  const SocialPlatform._(this.id, this.label, this.hint, this._buildUrl);

  /// The public profile URL for [handle], or null when [handle] is blank.
  Uri? profileUrl(String handle) {
    final normalized = normalizeHandle(handle);
    if (normalized.isEmpty) return null;
    return Uri.tryParse(_buildUrl(normalized));
  }

  /// Strips a leading `@` and, if the user pasted a full profile URL, reduces
  /// it to the last path segment so we always store a bare handle.
  static String normalizeHandle(String raw) {
    var handle = raw.trim();
    if (handle.isEmpty) return '';
    if (handle.startsWith('http://') || handle.startsWith('https://')) {
      final uri = Uri.tryParse(handle);
      if (uri != null) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        handle = segments.isEmpty ? '' : segments.last;
      }
    }
    return handle.replaceFirst(RegExp(r'^@'), '').trim();
  }

  /// All supported platforms, in display order.
  static const List<SocialPlatform> all = [
    SocialPlatform._('instagram', 'Instagram', '@username', _instagramUrl),
    SocialPlatform._('facebook', 'Facebook', 'username or profile', _facebookUrl),
    SocialPlatform._('tiktok', 'TikTok', '@username', _tiktokUrl),
    SocialPlatform._('snapchat', 'Snapchat', 'username', _snapchatUrl),
    SocialPlatform._('linkedin', 'LinkedIn', 'profile id', _linkedinUrl),
  ];

  /// Looks up a platform by its [id], or null if unknown.
  static SocialPlatform? byId(String id) {
    for (final platform in all) {
      if (platform.id == id) return platform;
    }
    return null;
  }
}

String _instagramUrl(String handle) => 'https://instagram.com/$handle';
String _facebookUrl(String handle) => 'https://facebook.com/$handle';
String _tiktokUrl(String handle) => 'https://www.tiktok.com/@$handle';
String _snapchatUrl(String handle) => 'https://www.snapchat.com/add/$handle';
String _linkedinUrl(String handle) => 'https://www.linkedin.com/in/$handle';
