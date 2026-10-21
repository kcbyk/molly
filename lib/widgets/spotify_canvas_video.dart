import 'package:flutter/material.dart';
import 'spotify_canvas_video_stub.dart'
    if (dart.library.html) 'spotify_canvas_video_web.dart' as platform;

class SpotifyCanvasVideo extends StatelessWidget {
  final String videoUrl;
  final double borderRadius;

  const SpotifyCanvasVideo({
    super.key,
    required this.videoUrl,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return platform.buildCanvasVideo(
      videoUrl: videoUrl,
      borderRadius: borderRadius,
    );
  }
}
