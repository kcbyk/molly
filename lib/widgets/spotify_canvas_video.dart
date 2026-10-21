import 'package:flutter/material.dart';

import 'spotify_canvas_video_stub.dart'
    if (dart.library.html) 'spotify_canvas_video_web.dart' as platform;

/// Spotify Canvas (canvaz.scdn.co üzerindeki sessiz MP4 döngüsü).
///
/// Web'de gerçek `<video>` olarak oynar; native'de kapak fotoğrafına düşer.
/// [isActive] false iken video DOM'dan kaldırılır — böylece oynatıcı kapalıyken
/// arka planda video çalmaya devam edip CPU/GPU tüketmez.
class SpotifyCanvasVideo extends StatelessWidget {
  final String videoUrl;
  final String? coverUrl;
  final double borderRadius;
  final bool isActive;

  const SpotifyCanvasVideo({
    super.key,
    required this.videoUrl,
    this.coverUrl,
    this.borderRadius = 24.0,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return platform.buildCanvasVideo(
      videoUrl: videoUrl,
      coverUrl: coverUrl,
      borderRadius: borderRadius,
      isActive: isActive,
    );
  }
}
