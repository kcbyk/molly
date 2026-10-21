import 'package:flutter/material.dart';

/// Mobil/masaüstünde Canvas MP4'ü oynatamıyoruz; kapak fotoğrafını
/// tam ekran arka plan olarak gösteriyoruz (siyah kutudan çok daha iyi).
Widget buildCanvasVideo({
  required String videoUrl,
  String? coverUrl,
  required double borderRadius,
  bool isActive = true,
}) {
  if (coverUrl != null && coverUrl.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 1080,
        errorBuilder: (context, error, stack) => _fallback(borderRadius),
      ),
    );
  }
  return _fallback(borderRadius);
}

Widget _fallback(double borderRadius) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: const Center(
      child: Icon(Icons.music_video_rounded, color: Colors.white24, size: 48),
    ),
  );
}
