// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebCanvasVideoWidget extends StatefulWidget {
  final String videoUrl;
  final double borderRadius;

  const WebCanvasVideoWidget({
    super.key,
    required this.videoUrl,
    required this.borderRadius,
  });

  @override
  State<WebCanvasVideoWidget> createState() => _WebCanvasVideoWidgetState();
}

class _WebCanvasVideoWidgetState extends State<WebCanvasVideoWidget> {
  late String _viewId;
  html.VideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _viewId = 'canvas_video_${widget.videoUrl.hashCode.abs()}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final video = html.VideoElement()
          ..src = widget.videoUrl
          ..autoplay = true
          ..loop = true
          ..muted = true
          ..setAttribute('playsinline', 'true')
          ..setAttribute('webkit-playsinline', 'true')
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '${widget.borderRadius}px'
          ..style.border = 'none';

        _videoElement = video;
        return video;
      },
    );
  }

  @override
  void didUpdateWidget(covariant WebCanvasVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _videoElement?.src = widget.videoUrl;
      _videoElement?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

Widget buildCanvasVideo({
  required String videoUrl,
  required double borderRadius,
}) {
  return WebCanvasVideoWidget(
    videoUrl: videoUrl,
    borderRadius: borderRadius,
  );
}
