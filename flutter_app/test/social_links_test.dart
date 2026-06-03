import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/services/social_links.dart';

void main() {
  group('SocialPlatform.normalizeHandle', () {
    test('strips a leading @ and surrounding whitespace', () {
      expect(SocialPlatform.normalizeHandle('  @ada  '), 'ada');
    });

    test('reduces a pasted profile URL to its last path segment', () {
      expect(SocialPlatform.normalizeHandle('https://instagram.com/ada/'),
          'ada');
      expect(
          SocialPlatform.normalizeHandle('https://www.tiktok.com/@ada'), 'ada');
    });

    test('returns empty for blank input', () {
      expect(SocialPlatform.normalizeHandle('   '), '');
    });
  });

  group('SocialPlatform.profileUrl', () {
    test('builds the right URL per platform', () {
      String url(String id) =>
          SocialPlatform.byId(id)!.profileUrl('ada').toString();
      expect(url('instagram'), 'https://instagram.com/ada');
      expect(url('facebook'), 'https://facebook.com/ada');
      expect(url('tiktok'), 'https://www.tiktok.com/@ada');
      expect(url('snapchat'), 'https://www.snapchat.com/add/ada');
      expect(url('linkedin'), 'https://www.linkedin.com/in/ada');
    });

    test('normalizes the handle before building the URL', () {
      expect(SocialPlatform.byId('instagram')!.profileUrl('@ada').toString(),
          'https://instagram.com/ada');
    });

    test('returns null for a blank handle', () {
      expect(SocialPlatform.byId('instagram')!.profileUrl('  '), isNull);
    });
  });

  test('all five named platforms are supported', () {
    expect(SocialPlatform.all.map((p) => p.id).toSet(), {
      'instagram',
      'facebook',
      'tiktok',
      'snapchat',
      'linkedin',
    });
  });

  test('byId returns null for an unknown platform', () {
    expect(SocialPlatform.byId('myspace'), isNull);
  });
}
