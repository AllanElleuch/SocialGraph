import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/painters/constellation_layout.dart';

ConstellationGroup g(String tag, Offset center) => ConstellationGroup(
      tag: tag,
      constellation: tag,
      center: center,
      index: 0,
    );

void main() {
  group('constellationTagAt', () {
    final labels = [
      g('UTT', const Offset(0, 0)),
      g('Yoga', const Offset(1000, 0)),
    ];

    test('returns the tag when tapping near its label (below the center)', () {
      // At scale 1 the label sits 150 below the center.
      expect(constellationTagAt(const Offset(0, 150), 1.0, labels), 'UTT');
    });

    test('returns null when the tap is far from every label', () {
      expect(constellationTagAt(const Offset(500, 500), 1.0, labels), isNull);
    });

    test('picks the closest label when two are in range', () {
      // Near Yoga (1000,150), far from UTT.
      expect(constellationTagAt(const Offset(1000, 150), 1.0, labels), 'Yoga');
    });

    test('hit radius and label offset scale with zoom (1/scale)', () {
      // At scale 1: UTT label center is (0,150), radius 180 -> (0,400) is 250
      // away -> out of range.
      expect(constellationTagAt(const Offset(0, 400), 1.0, labels), isNull);
      // Zoomed out (scale 0.5): label center (0,300), radius 360 -> (0,400) is
      // 100 away -> now in range.
      expect(constellationTagAt(const Offset(0, 400), 0.5, labels), 'UTT');
    });

    test('returns null for a non-positive scale', () {
      expect(constellationTagAt(Offset.zero, 0, labels), isNull);
    });
  });

  group('distanceToSegment', () {
    test('perpendicular distance to a point beside the segment', () {
      // Segment along the x-axis from (0,0) to (10,0); point at (5,3).
      expect(distanceToSegment(const Offset(5, 3), const Offset(0, 0),
          const Offset(10, 0)), 3);
    });

    test('clamps to the nearest endpoint when past the segment', () {
      // Point beyond (10,0): nearest point is the endpoint (10,0).
      expect(distanceToSegment(const Offset(13, 4), const Offset(0, 0),
          const Offset(10, 0)), 5); // sqrt(3^2 + 4^2)
    });

    test('zero when the point is on the segment', () {
      expect(distanceToSegment(const Offset(4, 0), const Offset(0, 0),
          const Offset(10, 0)), 0);
    });

    test('degenerate segment (a == b) is distance to the point', () {
      expect(distanceToSegment(const Offset(3, 4), const Offset(0, 0),
          const Offset(0, 0)), 5);
    });
  });
}
