import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_graph/models/contact.dart';
import 'package:social_graph/models/graph_node.dart';
import 'package:social_graph/painters/graph_painter.dart';

/// Builds a solid-colour [ui.Image] without going through PNG decoding.
Future<ui.Image> solidImage(Color color, {int size = 20}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(size, size);
}

Future<ui.Image> renderPainter(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  return recorder
      .endRecording()
      .toImage(size.width.toInt(), size.height.toInt());
}

({int r, int g, int b, int a}) pixelAt(ByteData data, int x, int y, int w) {
  final o = (y * w + x) * 4;
  return (
    r: data.getUint8(o),
    g: data.getUint8(o + 1),
    b: data.getUint8(o + 2),
    a: data.getUint8(o + 3),
  );
}

Contact makeContact(String id) => Contact(
      id: id,
      firstName: 'A',
      lastName: id,
      tags: const [],
      locationMet: '',
      connections: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(100, 100);
  final now = DateTime(2026, 6, 1);

  GraphNode centerNode() => GraphNode(
        id: 'a',
        name: 'Ada',
        data: makeContact('a'),
        x: 50,
        y: 50,
      );

  test('draws the contact photo at the node center when provided', () async {
    final photo = await solidImage(const Color(0xFFFF0000)); // pure red
    final painter = GraphPainter(
      nodes: [centerNode()],
      links: const [],
      pivot: PivotType.mutual,
      minTime: 0,
      maxTime: 0,
      photos: {'a': photo},
      now: now,
    );

    final rendered = await renderPainter(painter, size);
    final data = (await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final px = pixelAt(data, 50, 50, size.width.toInt());

    // The photo (red) fills the node body — red dominant, little blue.
    expect(px.r, greaterThan(180));
    expect(px.b, lessThan(80));

    photo.dispose();
    rendered.dispose();
  });

  test('renders a star core when no photo is present', () async {
    final painter = GraphPainter(
      nodes: [centerNode()],
      links: const [],
      pivot: PivotType.mutual,
      minTime: 0,
      maxTime: 0,
      now: now,
    );

    final rendered = await renderPainter(painter, size);
    final data = (await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final center = pixelAt(data, 50, 50, size.width.toInt());
    final corner = pixelAt(data, 2, 2, size.width.toInt());

    // A bright, opaque star core is drawn at the node center...
    expect(center.a, greaterThan(200));
    // ...while empty sky stays transparent.
    expect(corner.a, lessThan(40));

    rendered.dispose();
  });
}
