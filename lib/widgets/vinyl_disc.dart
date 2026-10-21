import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';

class VinylDisc extends StatelessWidget {
  final Song song;
  final double size;
  final double holeSize;
  final bool isCurrent;
  final Color holeBg;
  final bool animateSpin;
  final AnimationController? spinController;

  const VinylDisc({
    super.key,
    required this.song,
    this.size = 58,
    this.holeSize = 16,
    this.isCurrent = false,
    this.holeBg = AppColors.background,
    this.animateSpin = false,
    this.spinController,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = song.coverUrl != null && song.coverUrl!.isNotEmpty;

    Widget discContent = Stack(
      alignment: Alignment.center,
      children: [
        // Base: Cover Image scaled to fill edge-to-edge with no gaps or letterboxing
        if (hasCover)
          ClipOval(
            child: Transform.scale(
              scale: 1.25, // Eliminates any YouTube 16:9 black letterbox bars
              child: Image.network(
                song.coverUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Küçük daire için tam boy kapak çözmeye gerek yok (bellek/CPU tasarrufu)
                cacheWidth: (size * 2).round(),
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: song.gradient,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: song.gradient,
                    ),
                  );
                },
              ),
            ),
          )
        else
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: song.gradient,
            ),
          ),

        // Subtle vinyl groove overlay & glossy rim
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.0,
            ),
            gradient: RadialGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.35),
              ],
              stops: const [0.65, 0.90, 1.0],
            ),
          ),
        ),

        // Spindle Hole
        Container(
          width: holeSize,
          height: holeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: holeBg,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ],
    );

    Widget disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  spreadRadius: 2.0,
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: AppColors.background,
                  spreadRadius: 1.0,
                  blurRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: discContent,
    );

    if (animateSpin && spinController != null) {
      return RotationTransition(
        turns: spinController!,
        child: disc,
      );
    }

    return disc;
  }
}
