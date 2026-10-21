// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class WebCanvasVideoWidget extends StatefulWidget {
  final String videoUrl;
  final String? coverUrl;
  final double borderRadius;
  final bool isActive;

  const WebCanvasVideoWidget({
    super.key,
    required this.videoUrl,
    required this.borderRadius,
    this.coverUrl,
    this.isActive = true,
  });

  @override
  State<WebCanvasVideoWidget> createState() => _WebCanvasVideoWidgetState();
}

class _WebCanvasVideoWidgetState extends State<WebCanvasVideoWidget> {
  static int _viewCounter = 0;

  late final String _viewId = 'molly_canvas_${_viewCounter++}';
  html.VideoElement? _videoElement;
  bool _factoryRegistered = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _ensureFactory();
    }
  }

  void _ensureFactory() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      return _videoElement ??= _createVideo();
    });
  }

  html.VideoElement _createVideo() {
    final video = html.VideoElement()
      ..autoplay = true
      ..loop = true
      ..muted = true
      ..controls = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.border = 'none'
      ..style.borderRadius = '${widget.borderRadius}px'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..setAttribute('preload', 'auto')
      ..setAttribute('disablepictureinpicture', 'true');

    final cover = widget.coverUrl;
    if (cover != null && cover.isNotEmpty) {
      video.setAttribute('poster', cover);
    }

    // Jestler Flutter'a geçsin (kaydırma / tap)
    video.style.setProperty('pointer-events', 'none');

    video.onError.listen((_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    });

    video.src = widget.videoUrl;
    _safePlay(video);

    _videoElement = video;
    return video;
  }

  void _safePlay(html.VideoElement? video) {
    if (video == null) return;
    // Otomatik oynatma engellenirse sessizce geç; kapak görünür kalır.
    video.play().catchError((_) => null);
  }

  @override
  void didUpdateWidget(covariant WebCanvasVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _failed = false;
      final video = _videoElement;
      if (video != null) {
        video.src = widget.videoUrl;
        video.load();
        _safePlay(video);
      }
    }

    if (oldWidget.coverUrl != widget.coverUrl) {
      final video = _videoElement;
      final cover = widget.coverUrl;
      if (video != null && cover != null && cover.isNotEmpty) {
        video.setAttribute('poster', cover);
      }
    }

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _ensureFactory();
        _safePlay(_videoElement);
      } else {
        _videoElement?.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kapalıyken veya hata durumunda video DOM'a hiç eklenmez.
    if (!widget.isActive || _failed) {
      return _CoverFallback(
        coverUrl: widget.coverUrl,
        borderRadius: widget.borderRadius,
      );
    }

    _ensureFactory();
    return Stack(
      fit: StackFit.expand,
      children: [
        // Yüklenirken / video siyahken arkada kapak dursun.
        _CoverFallback(
          coverUrl: widget.coverUrl,
          borderRadius: widget.borderRadius,
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: HtmlElementView(viewType: _viewId),
        ),
      ],
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final String? coverUrl;
  final double borderRadius;

  const _CoverFallback({required this.coverUrl, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url.isNotEmpty)
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 1080,
              errorBuilder: (context, error, stack) => _empty(),
            )
          : _empty(),
    );
  }

  Widget _empty() {
    return const Center(
      child: Icon(Icons.music_video_rounded, color: Colors.white24, size: 48),
    );
  }
}

Widget buildCanvasVideo({
  required String videoUrl,
  String? coverUrl,
  required double borderRadius,
  bool isActive = true,
}) {
  return WebCanvasVideoWidget(
    videoUrl: videoUrl,
    coverUrl: coverUrl,
    borderRadius: borderRadius,
    isActive: isActive,
  );
}
