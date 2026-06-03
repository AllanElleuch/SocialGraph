import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A full-screen, pinch-to-zoom viewer for a single image (e.g. a contact
/// photo). Tap anywhere or the close button to dismiss. Shares a [heroTag] with
/// the thumbnail so the open/close animates smoothly.
class FullScreenPhoto extends StatelessWidget {
  final Uint8List bytes;
  final String? heroTag;

  const FullScreenPhoto({super.key, required this.bytes, this.heroTag});

  /// Pushes the viewer as a translucent route over the current screen.
  static Future<void> show(
    BuildContext context,
    Uint8List bytes, {
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            FullScreenPhoto(bytes: bytes, heroTag: heroTag),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(bytes, fit: BoxFit.contain);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap anywhere to dismiss.
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: heroTag != null
                    ? Hero(tag: heroTag!, child: image)
                    : image,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
