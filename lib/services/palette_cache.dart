import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Kapak fotoğrafından çıkarılan renkler.
typedef SongPalette = ({Color? dominant, Color? muted, Color? vibrant});

/// Aynı kapak için renk çıkarımını TEK kez yapar.
/// Ana ekran ve "Şu an çalıyor" ekranı aynı cache'i kullandığı için
/// şarkı değişiminde görüntü iki kez indirilip analiz edilmez.
class PaletteCache {
  static final Map<String, SongPalette> _done = {};
  static final Map<String, Future<SongPalette?>> _pending = {};

  static SongPalette? peek(String? url) {
    if (url == null || url.isEmpty) return null;
    return _done[url];
  }

  static Future<SongPalette?> load(String url) {
    final cached = _done[url];
    if (cached != null) return Future.value(cached);

    final pending = _pending[url];
    if (pending != null) return pending;

    final future = _extract(url);
    _pending[url] = future;
    return future.whenComplete(() => _pending.remove(url));
  }

  static Future<SongPalette?> _extract(String url) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(96, 96),
        maximumColorCount: 8,
      );
      final result = (
        dominant: palette.dominantColor?.color ?? palette.vibrantColor?.color,
        muted: palette.mutedColor?.color ?? palette.darkVibrantColor?.color,
        vibrant: palette.vibrantColor?.color,
      );
      _done[url] = result;
      return result;
    } catch (_) {
      return null;
    }
  }
}
