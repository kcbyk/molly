import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'vinyl_disc.dart';

class SongRow extends StatefulWidget {
  final Song song;
  final bool isCurrent;
  final bool isLiked;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isLibraryTab;
  final VoidCallback onPlay;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleDownload;
  final VoidCallback onOpenMenu;

  const SongRow({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isLiked,
    required this.isDownloaded,
    this.isDownloading = false,
    required this.isLibraryTab,
    required this.onPlay,
    required this.onToggleLike,
    required this.onToggleDownload,
    required this.onOpenMenu,
  });

  @override
  State<SongRow> createState() => _SongRowState();
}

class _SongRowState extends State<SongRow> with SingleTickerProviderStateMixin {
  late AnimationController _popController;
  late Animation<double> _popAnimation;

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _popAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.3)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 60),
    ]).animate(_popController);
  }

  @override
  void didUpdateWidget(covariant SongRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      _popController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.cardBg,
        highlightColor: AppColors.cardBg,
        onTap: widget.onPlay,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(
            children: [
              // Vinyl Disc
              VinylDisc(
                song: widget.song,
                size: 58,
                holeSize: 16,
                isCurrent: widget.isCurrent,
              ),
              const SizedBox(width: 14),

              // Title and Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.song.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isCurrent
                            ? AppColors.limeAccent
                            : AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.song.artist} · ${widget.song.dur}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action button: Download (discover) or More options (library)
              if (!widget.isLibraryTab)
                _buildIconButton(
                  onTap: widget.isDownloading ? () {} : widget.onToggleDownload,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: widget.isDownloading
                          ? SizedBox(
                              key: const ValueKey('loading'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.textMuted,
                                backgroundColor:
                                    AppColors.textMuted.withValues(alpha: 0.18),
                              ),
                            )
                          : widget.isDownloaded
                              ? Container(
                                  key: const ValueKey('done'),
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: AppColors.limeAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: AppIcons.check(
                                      size: 16,
                                      color: AppColors.background,
                                    ),
                                  ),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('idle'),
                                  child: AppIcons.download(
                                    size: 24,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                    ),
                  ),
                )
              else
                _buildIconButton(
                  onTap: widget.onOpenMenu,
                  child: AppIcons.moreVertical(
                    size: 24,
                    color: AppColors.textMuted,
                  ),
                ),

              // Like / Heart button
              _buildIconButton(
                onTap: widget.onToggleLike,
                child: ScaleTransition(
                  scale: _popAnimation,
                  child: AppIcons.heart(
                    size: 24,
                    isLiked: widget.isLiked,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
      {required VoidCallback onTap, required Widget child}) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: AppColors.playerBg,
          highlightColor: AppColors.playerBg,
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

