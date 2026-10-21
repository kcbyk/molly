import 'package:flutter/material.dart';

Widget buildCanvasVideo({
  required String videoUrl,
  required double borderRadius,
}) {
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
