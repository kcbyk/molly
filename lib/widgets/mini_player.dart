import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'vinyl_disc.dart';

class MiniPlayer extends StatefulWidget {
  final Song currentSong;
  final bool isPlaying;
  final double progress; // 0.0 to 1.0
  final AnimationController spinController;
  final VoidCallback onTogglePlay;
  final VoidCallback? onTap;
  final ValueChanged<double>? onSeekRatio;
  final Color? smartBgColor;

  const MiniPlayer({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.progress,
    required this.spinController,
    required this.onTogglePlay,
    this.onTap,
    this.onSeekRatio,
    this.smartBgColor,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _isScrubbing = false;
  double _scrubRatio = 0.0;

  void _handleSeek(Offset localPosition, double totalWidth) {
    if (totalWidth <= 0) return;
    final ratio = (localPosition.dx / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _scrubRatio = ratio;
    });
  }

  void _commitSeek() {
    widget.onSeekRatio?.call(_scrubRatio);
    setState(() {
      _isScrubbing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = _isScrubbing ? _scrubRatio : widget.progress.clamp(0.0, 1.0);
    final cardBg = widget.smartBgColor ?? AppColors.playerBg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: cardBg.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Content Row (tapping anywhere opens the full-screen player)
            Positioned.fill(
              bottom: 6, // leave room for scrub bar at bottom
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: Row(
                      children: [
                        // Spinning Vinyl Disc
                        VinylDisc(
                          song: widget.currentSong,
                          size: 44,
                          holeSize: 12,
                          holeBg: cardBg,
                          animateSpin: true,
                          spinController: widget.spinController,
                        ),
                        const SizedBox(width: 12),

                        // Title and Artist
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.currentSong.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.currentSong.artist,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Play/Pause Button — Glassmorphic white circle matching the big player
                        GestureDetector(
                          onTap: widget.onTogglePlay,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: widget.isPlaying
                                  ? AppIcons.pause(size: 20, color: const Color(0xFFF4F4F6))
                                  : AppIcons.play(size: 20, color: const Color(0xFFF4F4F6)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── TikTok-Style Draggable / Scrubbable Progress Bar ──
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              height: 18, // Generous hit area for effortless touch & dragging
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalW = constraints.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      setState(() => _isScrubbing = true);
                      _handleSeek(details.localPosition, totalW);
                    },
                    onHorizontalDragUpdate: (details) {
                      _handleSeek(details.localPosition, totalW);
                    },
                    onHorizontalDragEnd: (details) {
                      _commitSeek();
                    },
                    onHorizontalDragCancel: () {
                      setState(() => _isScrubbing = false);
                    },
                    onTapDown: (details) {
                      setState(() => _isScrubbing = true);
                      _handleSeek(details.localPosition, totalW);
                    },
                    onTapUp: (details) {
                      _commitSeek();
                    },
                    child: Center(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: [
                          // Inactive Track (Darker semi-transparent white)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: _isScrubbing ? 5.0 : 3.0,
                            width: totalW,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),

                          // Active Track (Pure Crisp White)
                          AnimatedContainer(
                            duration: _isScrubbing
                                ? Duration.zero
                                : const Duration(milliseconds: 150),
                            height: _isScrubbing ? 5.0 : 3.0,
                            width: (totalW * effectiveProgress).clamp(0.0, totalW),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),

                          // TikTok Scrubbing Thumb Dot (appears when finger is touching/dragging)
                          if (_isScrubbing)
                            Positioned(
                              left: ((totalW * effectiveProgress) - 5).clamp(0.0, totalW - 10),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      blurRadius: 6,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
