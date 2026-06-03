import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/utils/text_sanitizer.dart';

void main() {
  group('sanitizeUtf16', () {
    test('returns well-formed strings unchanged', () {
      expect(sanitizeUtf16('Ada Lovelace'), 'Ada Lovelace');
      expect(sanitizeUtf16(''), '');
      // A valid emoji (surrogate pair) is preserved intact.
      expect(sanitizeUtf16('Hi 😀'), 'Hi 😀');
    });

    test('replaces a lone high surrogate with U+FFFD', () {
      // 0xD83D is the high half of 😀 with no following low surrogate.
      final input = 'Bad${String.fromCharCode(0xD83D)}name';
      final out = sanitizeUtf16(input);
      expect(isWellFormedUtf16(out), isTrue);
      expect(out, 'Bad�name');
    });

    test('replaces a lone low surrogate with U+FFFD', () {
      final input = 'x${String.fromCharCode(0xDE00)}y';
      final out = sanitizeUtf16(input);
      expect(isWellFormedUtf16(out), isTrue);
      expect(out, 'x�y');
    });

    test('keeps a valid surrogate pair but fixes an adjacent lone half', () {
      // Valid 😀 (D83D DE00) followed by a lone high surrogate.
      final input = '\u{1F600}${String.fromCharCode(0xD83D)}';
      final out = sanitizeUtf16(input);
      expect(isWellFormedUtf16(out), isTrue);
      expect(out, '\u{1F600}�');
    });

    test('sanitized output encodes to valid UTF-8 (Firestore-safe)', () {
      final input = 'note ${String.fromCharCode(0xD83D)}';
      // Encoding a lone surrogate throws; the sanitized string must not.
      expect(() => sanitizeUtf16(input).runes.toList(), returnsNormally);
      expect(isWellFormedUtf16(sanitizeUtf16(input)), isTrue);
    });
  });

  group('Contact.fromJson sanitization', () {
    test('cleans malformed UTF-16 in text fields', () {
      final json = {
        'id': 'a',
        'firstName': 'Jo${String.fromCharCode(0xD83D)}',
        'lastName': 'Doe',
        'notes': 'hi ${String.fromCharCode(0xDE00)}',
        'tags': ['ok', 'bad${String.fromCharCode(0xD83D)}'],
        'locationMet': '',
        'connections': <String>[],
      };

      final c = Contact.fromJson(json);

      expect(isWellFormedUtf16(c.firstName), isTrue);
      expect(isWellFormedUtf16(c.notes), isTrue);
      expect(c.tags.every(isWellFormedUtf16), isTrue);
      // The whole serialized form is well-formed, so toJson is Firestore-safe.
      expect(isWellFormedUtf16(c.displayName), isTrue);
    });
  });
}
