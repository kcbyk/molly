import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'spotify_canvas_video.dart';
import 'vinyl_disc.dart';

class NowPlayingScreen extends StatefulWidget {
  final Song song;
  final Song nextSong;
  final String contextTitle;
  final bool isPlaying;
  final int currentPositionSeconds;
  final bool isLiked;
  final bool isShuffle;
  final bool isRepeat;
  final AnimationController spinController;
  final VoidCallback onClose;
  final VoidCallback onTogglePlay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final ValueChanged<double> onSeek;
  final VoidCallback onPlayNext;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenLibrary;

  const NowPlayingScreen({
    super.key,
    required this.song,
    required this.nextSong,
    required this.contextTitle,
    required this.isPlaying,
    required this.currentPositionSeconds,
    required this.isLiked,
    required this.isShuffle,
    required this.isRepeat,
    required this.spinController,
    required this.onClose,
    required this.onTogglePlay,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleLike,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    required this.onSeek,
    required this.onPlayNext,
    required this.onOpenMenu,
    required this.onOpenLibrary,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _likePopController;
  late Animation<double> _likePopAnimation;
  double? _dragPosition;

  // Akıllı renk — kapaktan çıkarılır
  Color _bgTop = const Color(0xFF1A1A2E);
  Color _bgBottom = const Color(0xFF0A0A0D);
  String? _lastPaletteUrl;

  bool get _hasCanvas =>
      widget.song.canvasUrl != null && widget.song.canvasUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _likePopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _likePopAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 60),
    ]).animate(_likePopController);

    _extractPalette(widget.song);
  }

  @override
  void didUpdateWidget(covariant NowPlayingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      _likePopController.forward(from: 0.0);
    }
    if (oldWidget.song.id != widget.song.id) {
      _extractPalette(widget.song);
    }
  }

  Future<void> _extractPalette(Song song) async {
    final url = song.coverUrl;
    if (url == null || url.isEmpty || url == _lastPaletteUrl) return;
    _lastPaletteUrl = url;

    // In unit/widget tests without real network, skip PaletteGenerator
    if (WidgetsBinding.instance is! WidgetsFlutterBinding) {
      if (mounted) {
        setState(() {
          _bgTop = _darken(song.color1, 0.55);
          _bgBottom = const Color(0xFF0A0A0D);
        });
      }
      return;
    }

    try {
      final imageProvider = NetworkImage(url);
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100), // küçük boyut = hızlı analiz
        maximumColorCount: 8,
      );

      if (!mounted) return;

      // Dominant veya vibrant rengi seç, karanlık versiyonunu kullan
      final dominant =
          palette.dominantColor?.color ?? palette.vibrantColor?.color;
      final secondary =
          palette.mutedColor?.color ?? palette.darkVibrantColor?.color;

      if (dominant != null) {
        setState(() {
          // Rengi koyulaştır — Spotify gibi koyu ama renkli
          _bgTop = _darken(dominant, 0.55);
          _bgBottom = _darken(secondary ?? dominant, 0.80);
        });
      }
    } catch (_) {
      // Palette çıkarma başarısız → song.color1/color2'yi kullan
      if (mounted) {
        setState(() {
          _bgTop = _darken(song.color1, 0.55);
          _bgBottom = const Color(0xFF0A0A0D);
        });
      }
    }
  }

  /// Rengi belirtilen miktarda koyulaştırır (0.0 = değişmez, 1.0 = siyah)
  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * (1 - amount)).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void dispose() {
    _likePopController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final s = math.max(0, totalSeconds);
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dur = widget.song.durationSeconds;
    final currentPos = _dragPosition?.toInt() ?? widget.currentPositionSeconds;
    final posClamped = currentPos.clamp(0, dur);
    final remaining = dur - posClamped;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── BACKGROUND ────────────────────────────────────────────────────
          if (_hasCanvas)
            // Canvas → tam ekran video arka plan
            Positioned.fill(
              child: SpotifyCanvasVideo(
                videoUrl: widget.song.canvasUrl!,
                borderRadius: 0,
              ),
            )
          else
            // Canvas yok → kapaktan çıkarılan akıllı gradyan
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, _bgBottom, const Color(0xFF08080C)],
                    stops: const [0.0, 0.60, 1.0],
                  ),
                ),
              ),
            ),

          // Canvas üstüne gradient overlay (yazılar okunabilsin)
          if (_hasCanvas)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xBB000000),
                      Color(0xEE000000),
                    ],
                    stops: [0.0, 0.18, 0.52, 0.78, 1.0],
                  ),
                ),
              ),
            ),

          // ── CONTENT ───────────────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableH = constraints.maxHeight;
                final isCompact = availableH < 720;
                // Kapak fotoğrafı boyutu: mevcut alanın üst yarısını dolduracak şekilde
                final coverSize =
                    (availableH * 0.42).clamp(180.0, 340.0);

                return Column(
                  children: [
                    // TOP BAR
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) {
                        if ((d.primaryDelta ?? 0) > 7) widget.onClose();
                      },
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) > 150) widget.onClose();
                      },
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8, isCompact ? 6 : 12, 8, 0),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                width: 38,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 44, minHeight: 44),
                                  onPressed: widget.onClose,
                                  icon: AppIcons.chevronDown(
                                      size: 26,
                                      color: const Color(0xFFF4F4F6)),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'ŞU AN ÇALIYOR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.4,
                                        color: Color(0xB8F4F4F6),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.contextTitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 44, minHeight: 44),
                                  onPressed: widget.onOpenMenu,
                                  icon: AppIcons.moreHorizontal(
                                      size: 24,
                                      color: const Color(0xFFF4F4F6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // MIDDLE — Canvas varsa tıklanabilir boş alan; yoksa büyük kapak fotoğrafı
                    Expanded(
                      child: _hasCanvas
                          ? GestureDetector(
                              onTap: widget.onTogglePlay,
                              behavior: HitTestBehavior.translucent,
                              child: const SizedBox.expand(),
                            )
                          : Center(
                              child: GestureDetector(
                                onTap: widget.onTogglePlay,
                                child: AnimatedScale(
                                  scale: widget.isPlaying ? 1.0 : 0.92,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  child: Container(
                                    width: coverSize,
                                    height: coverSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _bgTop.withValues(alpha: 0.7),
                                          blurRadius: 60,
                                          offset: const Offset(0, 24),
                                          spreadRadius: 8,
                                        ),
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.55),
                                          blurRadius: 24,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: widget.song.coverUrl != null &&
                                              widget.song.coverUrl!.isNotEmpty
                                          ? Image.network(
                                              widget.song.coverUrl!,
                                              fit: BoxFit.cover,
                                              filterQuality: FilterQuality.high,
                                              errorBuilder: (c, e, s) =>
                                                  _fallbackCover(coverSize),
                                            )
                                          : _fallbackCover(coverSize),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // BOTTOM CONTROLS PANEL
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20, 0, 20, isCompact ? 12 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Şarkı bilgisi: isim + like (küçük kapak sadece canvas modunda)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Küçük kapak — SADECE canvas aktifken göster
                              if (_hasCanvas) ...[
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: widget.song.coverUrl != null &&
                                            widget.song.coverUrl!.isNotEmpty
                                        ? Image.network(
                                            widget.song.coverUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                              decoration: BoxDecoration(
                                                gradient: widget.song.gradient,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              gradient: widget.song.gradient,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],

                              // Şarkı adı + sanatçı
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.song.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        height: 1.2,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.song.artist,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Like butonu
                              GestureDetector(
                                onTap: widget.onToggleLike,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.centerRight,
                                  child: ScaleTransition(
                                    scale: _likePopAnimation,
                                    child: AppIcons.heart(
                                      size: 27,
                                      isLiked: widget.isLiked,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isCompact ? 12 : 18),

                          // Slider + süreler
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                              activeTrackColor: const Color(0xFFDADAE6),
                              inactiveTrackColor: const Color(0xFF2A2A35),
                              thumbColor: const Color(0xFFDADAE6),
                              overlayColor:
                                  Colors.white.withValues(alpha: 0.15),
                            ),
                            child: Slider(
                              min: 0.0,
                              max: dur.toDouble(),
                              value: posClamped.toDouble(),
                              onChanged: (val) =>
                                  setState(() => _dragPosition = val),
                              onChangeEnd: (val) {
                                widget.onSeek(val);
                                setState(() => _dragPosition = null);
                              },
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatTime(posClamped),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xB8F4F4F6),
                                    )),
                                Text('-${_formatTime(remaining)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xB8F4F4F6),
                                    )),
                              ],
                            ),
                          ),

                          SizedBox(height: isCompact ? 6 : 12),

                          // Oynatma kontrolleri
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                iconSize: 24,
                                onPressed: widget.onToggleShuffle,
                                icon: AppIcons.shuffle(
                                  size: 24,
                                  color: widget.isShuffle
                                      ? const Color(0xFFF4F4F6)
                                      : const Color(0x80F4F4F6),
                                ),
                              ),
                              IconButton(
                                iconSize: 34,
                                onPressed: widget.onPrevious,
                                icon: AppIcons.prev(
                                    size: 34,
                                    color: const Color(0xFFF4F4F6)),
                              ),
                              GestureDetector(
                                onTap: widget.onTogglePlay,
                                child: Container(
                                  width: isCompact ? 64 : 72,
                                  height: isCompact ? 64 : 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.16),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.24),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: widget.isPlaying
                                        ? AppIcons.pause(
                                            size: isCompact ? 26 : 30,
                                            color: const Color(0xFFF4F4F6))
                                        : AppIcons.play(
                                            size: isCompact ? 26 : 30,
                                            color: const Color(0xFFF4F4F6)),
                                  ),
                                ),
                              ),
                              IconButton(
                                iconSize: 34,
                                onPressed: widget.onNext,
                                icon: AppIcons.next(
                                    size: 34,
                                    color: const Color(0xFFF4F4F6)),
                              ),
                              IconButton(
                                iconSize: 24,
                                onPressed: widget.onToggleRepeat,
                                icon: AppIcons.repeat(
                                  size: 24,
                                  color: widget.isRepeat
                                      ? const Color(0xFFF4F4F6)
                                      : const Color(0x80F4F4F6),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isCompact ? 10 : 16),

                          // SIRADAKİ kartı
                          Container(
                            height: 60,
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0A0D)
                                  .withValues(alpha: 0.50),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: widget.onPlayNext,
                                    child: Row(
                                      children: [
                                        VinylDisc(
                                          song: widget.nextSong,
                                          size: 42,
                                          holeSize: 12,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'SIRADAKİ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.2,
                                                  color: Color(0xB8F4F4F6),
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                '${widget.nextSong.title} · ${widget.nextSong.artist}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onOpenLibrary,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: AppIcons.queuePlaylist(
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: widget.song.gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 64),
      ),
    );
  }
}


