import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Native Canvas oynatıcı.
///
/// Spotify Canvas dosyaları sessiz MP4 döngüleridir. Video hazırlanırken veya
/// oynatma başarısız olursa kapak görseline düşer; böylece oynatıcı siyah
/// kalmaz. Web platformu ayrı olarak spotify_canvas_video_web.dart kullanır.
Widget buildCanvasVideo({
  required String videoUrl,
  String? coverUrl,
  required double borderRadius,
  bool isActive = true,
}) {
  return _NativeCanvasVideo(
    videoUrl: videoUrl,
    coverUrl: coverUrl,
    borderRadius: borderRadius,
    isActive: isActive,
  );
}

class _NativeCanvasVideo extends StatefulWidget {
  final String videoUrl;
  final String? coverUrl;
  final double borderRadius;
  final bool isActive;

  const _NativeCanvasVideo({
    required this.videoUrl,
    required this.coverUrl,
    required this.borderRadius,
    required this.isActive,
  });

  @override
  State<_NativeCanvasVideo> createState() => _NativeCanvasVideoState();
}

class _NativeCanvasVideoState extends State<_NativeCanvasVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final loadId = ++_loadId;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);

      if (!mounted || loadId != _loadId) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _ready = true;
        _failed = false;
      });

      if (widget.isActive) {
        try {
          await controller.play();
        } catch (_) {
          // Bazı cihazlar ilk autoplay çağrısını reddedebilir; kapak yedeği
          // yine görünür kalır.
        }
      }
    } catch (_) {
      await controller.dispose();
      if (!mounted || loadId != _loadId) return;
      setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant _NativeCanvasVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      final oldController = _controller;
      _controller = null;
      _ready = false;
      _failed = false;
      _loadId++;
      oldController?.dispose();
      setState(() {});
      _loadVideo();
      return;
    }

    final controller = _controller;
    if (controller == null || !_ready || oldWidget.isActive == widget.isActive) {
      return;
    }

    if (widget.isActive) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _loadId++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || _failed || controller == null) {
      return _coverFallback();
    }

    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return _coverFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  Widget _coverFallback() {
    final cover = widget.coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: (cover != null && cover.isNotEmpty)
          ? Image.network(
              cover,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 1080,
              errorBuilder: (context, error, stack) => _emptyFallback(),
            )
          : _emptyFallback(),
    );
  }

  Widget _emptyFallback() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: const Center(
        child: Icon(Icons.music_video_rounded, color: Colors.white24, size: 48),
      ),
    );
  }
}
