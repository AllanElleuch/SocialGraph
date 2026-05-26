import 'contact.dart';

class GraphNode {
  final String id;
  final String name;
  final Contact data;
  double x;
  double y;
  double vx;
  double vy;
  double? fx; // fixed x (during drag)
  double? fy; // fixed y (during drag)

  GraphNode({
    required this.id,
    required this.name,
    required this.data,
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
    this.fx,
    this.fy,
  });
}

class GraphLink {
  final String sourceId;
  final String targetId;
  final String type; // 'connection' | 'time'

  GraphLink({
    required this.sourceId,
    required this.targetId,
    required this.type,
  });
}
