import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/services/tag_rules.dart';

void main() {
  group('isLinkingTag', () {
    test('the Imported tag never links (case-insensitive)', () {
      expect(isLinkingTag('Imported'), isFalse);
      expect(isLinkingTag('imported'), isFalse);
      expect(isLinkingTag('  IMPORTED '), isFalse);
    });

    test('blank tags never link', () {
      expect(isLinkingTag(''), isFalse);
      expect(isLinkingTag('   '), isFalse);
    });

    test('ordinary tags link', () {
      expect(isLinkingTag('Work'), isTrue);
      expect(isLinkingTag('Family'), isTrue);
    });
  });

  test('linkingTags drops Imported and blanks, keeps order', () {
    expect(
      linkingTags(['Imported', 'Work', '', 'Gym', 'imported']),
      ['Work', 'Gym'],
    );
  });

  group('primaryLinkingTag', () {
    test('skips Imported to find the first real tag', () {
      expect(primaryLinkingTag(['Imported', 'Work']), 'Work');
      expect(primaryLinkingTag(['Work', 'Imported']), 'Work');
    });

    test('is empty when only Imported / no tags', () {
      expect(primaryLinkingTag(['Imported']), '');
      expect(primaryLinkingTag([]), '');
    });
  });
}
