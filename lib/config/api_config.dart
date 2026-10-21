import 'package:flutter/foundation.dart';

class ApiConfig {
  /// RapidAPI Keys provided by user for youtube-mp36
  static final List<String> apiKeys = [
    'adc4b7af04mshadb5aab86d5eff7p1946e8jsn61fbc4deba81',
    'f890c11bc2msh5d052433c7ad0d5p15925djsn5a5f8b7a00a3',
    '550292b6c2msh6f03553b10bc495p15d293jsn1a8ef5f8e47f',
  ];

  static int _currentKeyIndex = 0;

  static String get rapidApiKey {
    if (apiKeys.isEmpty) return '';
    return apiKeys[_currentKeyIndex % apiKeys.length];
  }

  static set rapidApiKey(String key) {
    final clean = key.trim();
    if (clean.isNotEmpty && !apiKeys.contains(clean)) {
      apiKeys.insert(0, clean);
      _currentKeyIndex = 0;
    }
  }

  /// Rotates to next working API key on rate limit or error
  static void rotateKey() {
    if (apiKeys.isNotEmpty) {
      _currentKeyIndex = (_currentKeyIndex + 1) % apiKeys.length;
    }
  }

  /// RapidAPI Host for full MP3 conversion and direct streaming
  static String rapidApiHost = 'youtube-mp36.p.rapidapi.com';

  static bool get hasKey => apiKeys.isNotEmpty && rapidApiKey.isNotEmpty;

  /// mp3-apisi.onrender.com personal download API key
  static const String mp3ApiKey = 'sk-24354e1074e69575b4f39796';
  static const String mp3ApiBase = 'https://mp3-apisi.onrender.com';

  // ─────────────────────────────────────────────────────────────
  //  Molly sunucusu (server/ klasörü)
  // ─────────────────────────────────────────────────────────────
  //
  // Öncelik sırası:
  //   1. --dart-define=API_BASE=https://molly-api.onrender.com
  //   2. Web: uygulamanın servis edildiği origin (sunucu Flutter'ı da
  //      servis ediyorsa hazır gelir) → yedek olarak localhost:3000
  //   3. Native: http://localhost:3000  (Android emülatör: 10.0.2.2)
  //
  // Sunucu bulunamazsa uygulama eski yedeklerle (Invidious, RapidAPI,
  // mp3-apisi) aynen çalışmaya devam eder.

  static const String apiBaseOverride = String.fromEnvironment('API_BASE');
  static const String devFallbackBase = 'http://localhost:3000';

  static String get apiBase {
    final override = apiBaseOverride.trim();
    if (override.isNotEmpty) return normalizeBase(override);
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && origin != 'null') return normalizeBase(origin);
      } catch (_) {}
      return devFallbackBase;
    }
    return devFallbackBase;
  }

  static String normalizeBase(String value) {
    var base = value.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }
}
