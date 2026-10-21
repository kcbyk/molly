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
}
