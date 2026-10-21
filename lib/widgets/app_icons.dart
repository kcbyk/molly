import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcons {
  static Widget search({double size = 20, Color color = const Color(0xFF9A9AA8)}) {
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="${_colorToHex(color)}" stroke-width="2" stroke-linecap="round">
  <path d="M11 4a7 7 0 100 14 7 7 0 000-14zm9 16l-3.5-3.5" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget download({double size = 24, Color color = const Color(0xFF9A9AA8)}) {
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="${_colorToHex(color)}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 4v11m0 0l-4-4m4 4l4-4M5 20h14" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget check({double size = 16, Color color = const Color(0xFF0A0A0D)}) {
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="${_colorToHex(color)}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
  <path d="M5 12.5l4.5 4.5L19 7.5" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget heart({
    double size = 24,
    required bool isLiked,
  }) {
    final fill = isLiked ? '#FF6B8A' : 'none';
    final stroke = isLiked ? '#FF6B8A' : '#9A9AA8';
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="$fill" stroke="$stroke" stroke-width="2" stroke-linejoin="round">
  <path d="M12 20s-7-4.4-7-10a4 4 0 017-2.6A4 4 0 0119 10c0 5.6-7 10-7 10z" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget chevronDown({double size = 26, Color color = const Color(0xFFF4F4F6)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M6 9l6 6 6-6" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget shuffle({double size = 24, required Color color}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M2 18h1.4c1.3 0 2.5-.6 3.3-1.7l6.1-8.6c.7-1.1 2-1.7 3.3-1.7H22" />
  <path d="M18 2l4 4-4 4" />
  <path d="M2 6h1.9c1.5 0 2.9.9 3.6 2.2" />
  <path d="M22 18h-5.9c-1.3 0-2.6-.7-3.3-1.8l-.5-.8" />
  <path d="M18 14l4 4-4 4" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget prev({double size = 34, Color color = const Color(0xFFF4F4F6)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="$hex" stroke="$hex" stroke-width="1.6" stroke-linejoin="round">
  <rect x="5" y="5.5" width="2.4" height="13" rx="1" />
  <path d="M19 6v12L9 12z" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget next({double size = 34, Color color = const Color(0xFFF4F4F6)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="$hex" stroke="$hex" stroke-width="1.6" stroke-linejoin="round">
  <rect x="16.6" y="5.5" width="2.4" height="13" rx="1" />
  <path d="M5 6v12l10-6z" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget repeat({double size = 24, required Color color}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M17 2l4 4-4 4" />
  <path d="M3 11v-1a4 4 0 014-4h14" />
  <path d="M7 22l-4-4 4-4" />
  <path d="M21 13v1a4 4 0 01-4 4H3" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget queuePlaylist({double size = 22, Color color = const Color(0xFF9A9AA8)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round">
  <path d="M4 7h12M4 12h12M4 17h7M18 14v6m-3-3h6" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget moreVertical({double size = 24, Color color = const Color(0xFF9A9AA8)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="$hex">
  <circle cx="12" cy="5" r="1.8" />
  <circle cx="12" cy="12" r="1.8" />
  <circle cx="12" cy="19" r="1.8" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget moreHorizontal({double size = 24, Color color = const Color(0xFFF4F4F6)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="$hex">
  <circle cx="5" cy="12" r="1.8" />
  <circle cx="12" cy="12" r="1.8" />
  <circle cx="19" cy="12" r="1.8" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget play({double size = 20, Color color = const Color(0xFF0A0A0D)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="$hex">
  <path d="M8 5v14l11-7z" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget pause({double size = 20, Color color = const Color(0xFF0A0A0D)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="$hex">
  <rect x="6" y="5" width="4" height="14" rx="1" />
  <rect x="14" y="5" width="4" height="14" rx="1" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  // Nav icons:
  static Widget navDiscover({double size = 22, required Color color}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 3a9 9 0 100 18 9 9 0 000-18zm3.5 5.5l-2 5-5 2 2-5 5-2z" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget navLibrary({double size = 22, required Color color}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 4v16M9 4v16M14.2 5.2l4.6 14.6" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget navLiked({double size = 22, required Color color}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 20s-7-4.4-7-10a4 4 0 017-2.6A4 4 0 0119 10c0 5.6-7 10-7 10z" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  // Menu action icons:
  static Widget share({double size = 22, Color color = const Color(0xFFF4F4F6)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 15V4m0 0L8 8m4-4l4 4M5 13v6h14v-6" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget addToPlaylist({double size = 22, Color color = const Color(0xFFF4F4F6)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 7h12M4 12h12M4 17h7M18 14v6m-3-3h6" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static Widget trash({double size = 22, Color color = const Color(0xFFFF6B8A)}) {
    final hex = _colorToHex(color);
    final rawSvg = '''
<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M5 7h14M10 11v6m4-6v6M6 7l1 13h10l1-13M9 7V4h6v3" />
</svg>
''';
    return SvgPicture.string(rawSvg, width: size, height: size);
  }

  static String _colorToHex(Color color) {
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}
