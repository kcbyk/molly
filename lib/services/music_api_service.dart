import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/song.dart';
import 'local_file_store.dart';

typedef SongArtwork = ({String? canvasUrl, String? coverUrl});

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._internal();
  factory MusicApiService() => _instance;
  MusicApiService._internal();

  final Map<String, String> _resolvedMp3Cache = {};
  // songId → local file path (file:/// or absolute)
  final Map<String, String> _localFilePaths = {};

  // Kapak + canvas sonuçları: sunucuya aynı şarkı için tekrar sormayalım.
  final Map<String, SongArtwork> _artworkCache = {};
  final Map<String, Future<SongArtwork>> _artworkInFlight = {};

  String? _chosenBase;
  DateTime? _probeFailedAt;

  // Sunucu yoksa her istekte 10-12 sn beklememek için kısa devre.
  int _networkFailures = 0;
  DateTime? _cooldownUntil;

  static const List<String> _invidiousInstances = [
    'https://invidious.f5.si',
    'https://invidious.protokolla.fi',
    'https://iv.melmac.space',
  ];

  // ─────────────────────────────────────────────────────────────
  //  Sunucu (server/) bağlantısı
  // ─────────────────────────────────────────────────────────────

  /// Uygulama açılırken sunucuyu erkenden yoklar; UI beklemez.
  Future<void> warmUp() async {
    await _base();
  }

  Future<String> _base() async {
    final chosen = _chosenBase;
    if (chosen != null) return chosen;

    final primary = ApiConfig.apiBase;
    final candidates = <String>{primary};
    // Sadece geliştirme sırasında (API_BASE verilmemiş + farklı port)
    // localhost:3000 yedeğine düş. Yayında override'a güven.
    if (kIsWeb &&
        ApiConfig.apiBaseOverride.isEmpty &&
        primary != ApiConfig.devFallbackBase) {
      candidates.add(ApiConfig.devFallbackBase);
    }

    final failedAt = _probeFailedAt;
    final coolingDown =
        failedAt != null && DateTime.now().difference(failedAt).inSeconds < 20;

    if (!coolingDown) {
      for (final base in candidates) {
        if (await _ping(base)) {
          _chosenBase = base;
          debugPrint('Molly sunucusu: $base');
          return base;
        }
      }
      _probeFailedAt = DateTime.now();
      debugPrint('Molly sunucusu bulunamadı, yerel yedekler kullanılacak.');
    }

    return candidates.length > 1 ? candidates.last : primary;
  }

  Future<bool> _ping(String base) async {
    try {
      final res = await http
          .get(Uri.parse('$base/api/health'))
          .timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  bool get _coolingDown {
    final until = _cooldownUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _registerNetworkFailure() {
    _networkFailures++;
    if (_networkFailures >= 2) {
      _cooldownUntil = DateTime.now().add(const Duration(seconds: 20));
    }
  }

  void _registerNetworkSuccess() {
    _networkFailures = 0;
    _cooldownUntil = null;
  }

  Future<http.Response?> _serverGet(
    String path, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_coolingDown) return null;
    try {
      final base = await _base();
      final res = await http.get(Uri.parse('$base$path')).timeout(timeout);
      if (res.statusCode == 200) {
        _registerNetworkSuccess();
        return res;
      }
      debugPrint('Sunucu $path → ${res.statusCode}');
    } catch (error) {
      debugPrint('Sunucu $path hatası: $error');
      _registerNetworkFailure();
    }
    return null;
  }

  Future<http.Response?> _serverPostJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_coolingDown) return null;
    try {
      final base = await _base();
      final res = await http
          .post(
            Uri.parse('$base$path'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(timeout);
      if (res.statusCode == 200) {
        _registerNetworkSuccess();
        return res;
      }
      debugPrint('Sunucu $path → ${res.statusCode}');
    } catch (error) {
      debugPrint('Sunucu $path hatası: $error');
      _registerNetworkFailure();
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  //  Arama
  // ─────────────────────────────────────────────────────────────

  /// Önce Molly sunucusu (Spotify/iTunes, tek istek, cache'li).
  /// Sunucu yoksa Invidious, en son yerel liste.
  Future<List<Song>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return Song.initialSongs;
    }

    // 1. Molly sunucusu — hızlı ve kapaklar kare
    final serverResults = await _searchViaServer(cleanQuery);
    if (serverResults != null && serverResults.isNotEmpty) {
      return serverResults;
    }

    // 2. Yedek: Invidious / YouTube
    for (final instance in _invidiousInstances) {
      try {
        final uri = Uri.parse(
          '$instance/api/v1/search?q=${Uri.encodeComponent(cleanQuery)}&type=video',
        );

        final response = await http.get(uri).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is List) {
            final List<Song> list = [];
            for (final item in decoded) {
              if (item is Map<String, dynamic> && item['type'] == 'video') {
                final song = Song.fromYouTube(item);
                if (_resolvedMp3Cache.containsKey(song.id)) {
                  list.add(song.copyWith(audioUrl: _resolvedMp3Cache[song.id]));
                } else {
                  list.add(song);
                }
              }
            }
            if (list.isNotEmpty) {
              return list;
            }
          }
        }
      } catch (e) {
        debugPrint('Search failed on $instance: $e');
      }
    }

    // 3. Son çare: başlangıç listesinde filtrele
    final q = cleanQuery.toLowerCase();
    return Song.initialSongs.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q);
    }).toList();
  }

  Future<List<Song>?> _searchViaServer(String query) async {
    final res = await _serverGet(
      '/api/search?q=${Uri.encodeComponent(query)}&limit=15',
      timeout: const Duration(seconds: 8),
    );
    if (res == null) return null;

    try {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is Map && decoded['results'] is List) {
        final list = (decoded['results'] as List)
            .whereType<Map>()
            .map((item) => Song.fromSpotify(Map<String, dynamic>.from(item)))
            .where((song) => song.id.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (error) {
      debugPrint('Sunucu arama cevabı okunamadı: $error');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  //  MP3 çözümleme
  //  Sıra: Molly sunucusu → RapidAPI (istemci) → mp3-apisi
  // ─────────────────────────────────────────────────────────────

  Future<Song> fetchMp3Stream(Song song) async {
    // Already resolved (could be local file path or URL)?
    if (song.audioUrl != null && song.audioUrl!.isNotEmpty) return song;

    final cacheKey = song.videoId ?? song.id;
    if (_resolvedMp3Cache.containsKey(cacheKey)) {
      return song.copyWith(audioUrl: _resolvedMp3Cache[cacheKey]);
    }

    // ── 0. Molly sunucusu (anahtarlar tarayıcıya hiç inmez) ──
    final viaServer = await _resolveStreamViaServer(song);
    if (viaServer != null) return viaServer;

    // ── 1. RapidAPI youtube-mp36 (doğrudan) ──
    String? vidId = song.videoId;
    if (vidId == null || vidId.isEmpty) {
      vidId = await _findVideoIdForSong(song.artist, song.title);
    }

    if (vidId != null && vidId.isNotEmpty) {
      final attempts =
          ApiConfig.apiKeys.isNotEmpty ? ApiConfig.apiKeys.length : 1;
      for (int i = 0; i < attempts; i++) {
        try {
          final uri = Uri.parse('https://${ApiConfig.rapidApiHost}/dl?id=$vidId');
          final response = await http.get(
            uri,
            headers: {
              'x-rapidapi-key': ApiConfig.rapidApiKey,
              'x-rapidapi-host': ApiConfig.rapidApiHost,
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            if (data is Map && data['status'] == 'ok' && data['link'] != null) {
              final link = data['link'].toString();
              final durationSec = (data['duration'] is num)
                  ? (data['duration'] as num).toInt()
                  : song.durationSeconds;
              final m = durationSec ~/ 60;
              final s = durationSec % 60;
              final formattedDur = '$m:${s.toString().padLeft(2, '0')}';
              _resolvedMp3Cache[cacheKey] = link;
              _resolvedMp3Cache[song.id] = link;
              debugPrint('RapidAPI başarılı → $link');
              return song.copyWith(
                audioUrl: link,
                videoId: vidId,
                durationSeconds: durationSec,
                dur: formattedDur,
              );
            } else if (data is Map && data['status'] == 'processing') {
              for (int retry = 0; retry < 3; retry++) {
                await Future.delayed(const Duration(seconds: 3));
                final retryRes = await http.get(
                  uri,
                  headers: {
                    'x-rapidapi-key': ApiConfig.rapidApiKey,
                    'x-rapidapi-host': ApiConfig.rapidApiHost,
                    'Accept': 'application/json',
                  },
                ).timeout(const Duration(seconds: 12));
                if (retryRes.statusCode == 200) {
                  final retryData = json.decode(utf8.decode(retryRes.bodyBytes));
                  if (retryData is Map &&
                      retryData['status'] == 'ok' &&
                      retryData['link'] != null) {
                    final link = retryData['link'].toString();
                    final durationSec = (retryData['duration'] is num)
                        ? (retryData['duration'] as num).toInt()
                        : song.durationSeconds;
                    final m = durationSec ~/ 60;
                    final s = durationSec % 60;
                    final formattedDur = '$m:${s.toString().padLeft(2, '0')}';
                    _resolvedMp3Cache[cacheKey] = link;
                    _resolvedMp3Cache[song.id] = link;
                    debugPrint('RapidAPI retry $retry başarılı → $link');
                    return song.copyWith(
                      audioUrl: link,
                      videoId: vidId,
                      durationSeconds: durationSec,
                      dur: formattedDur,
                    );
                  }
                }
              }
            }
          } else if (response.statusCode == 429 || response.statusCode == 403) {
            debugPrint('RapidAPI key limitli, rotasyon yapılıyor.');
            ApiConfig.rotateKey();
          }
        } catch (e) {
          debugPrint('RapidAPI hata (key $i): $e');
        }
      }
    }

    // ── 2. FALLBACK: mp3-apisi.onrender.com ──
    debugPrint('RapidAPI başarısız, mp3-apisi deneniyor → ${song.title}');
    final personalUrl = await _fetchMp3ViaPersonalApi(song);
    if (personalUrl != null && personalUrl.isNotEmpty) {
      return song.copyWith(audioUrl: personalUrl, videoId: vidId);
    }

    return song;
  }

  Future<Song?> _resolveStreamViaServer(Song song) async {
    // Sunucu hiç doğrulanmadıysa (ör. uygulama sunucusuz çalışıyor)
    // oynatmayı 12 sn geciktirme; doğrudan yerel yedeklere geç.
    if (_chosenBase == null) return null;

    final params = <String, String>{
      'artist': song.artist,
      'title': song.title,
    };
    if (song.videoId != null && song.videoId!.isNotEmpty) {
      params['videoId'] = song.videoId!;
    }

    final res = await _serverGet(
      '/api/audio?${Uri(queryParameters: params).query}',
      // Sunucu RapidAPI'de genelde <5 sn; uzarsa istemci yedeğine geç.
      timeout: const Duration(seconds: 12),
    );
    if (res == null) return null;

    try {
      final data = json.decode(utf8.decode(res.bodyBytes));
      if (data is! Map || data['ok'] != true) return null;
      final url = data['url']?.toString();
      if (url == null || url.isEmpty) return null;

      final cacheKey = song.videoId ?? song.id;
      _resolvedMp3Cache[cacheKey] = url;
      _resolvedMp3Cache[song.id] = url;

      final durationSeconds = data['durationSeconds'] is num
          ? (data['durationSeconds'] as num).toInt()
          : 0;
      final resolvedDuration =
          durationSeconds > 0 ? durationSeconds : song.durationSeconds;
      final m = resolvedDuration ~/ 60;
      final s = resolvedDuration % 60;

      final resolvedVideoId = data['videoId']?.toString();
      return song.copyWith(
        audioUrl: url,
        videoId: (resolvedVideoId != null && resolvedVideoId.isNotEmpty)
            ? resolvedVideoId
            : song.videoId,
        durationSeconds: resolvedDuration,
        dur: '$m:${s.toString().padLeft(2, '0')}',
      );
    } catch (error) {
      debugPrint('Sunucu MP3 cevabı okunamadı: $error');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  PRIMARY: mp3-apisi.onrender.com  (320kbps, yedek)
  // ─────────────────────────────────────────────────────────────

  Future<String?> _fetchMp3ViaPersonalApi(Song song) async {
    final query = '${song.artist} ${song.title}';
    final cacheKey = 'mpapisi_${song.id}';
    if (_resolvedMp3Cache.containsKey(cacheKey)) {
      return _resolvedMp3Cache[cacheKey];
    }

    try {
      final startUri = Uri(
        scheme: 'https',
        host: 'mp3-apisi.onrender.com',
        path: '/api/v1/instant',
        queryParameters: {
          'q': query,
          'key': ApiConfig.mp3ApiKey,
          'kalite': '320',
        },
      );
      final startRes =
          await http.get(startUri).timeout(const Duration(seconds: 12));
      if (startRes.statusCode != 200) return null;

      final startData = json.decode(utf8.decode(startRes.bodyBytes));
      if (startData is! Map || startData['ok'] != true) return null;

      final jobId = startData['job_id']?.toString();
      if (jobId == null || jobId.isEmpty) return null;

      debugPrint('mp3-apisi: job started → $jobId for "$query"');

      for (int i = 0; i < 35; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final statusUri = Uri(
          scheme: 'https',
          host: 'mp3-apisi.onrender.com',
          path: '/api/v1/status/$jobId',
          queryParameters: {'key': ApiConfig.mp3ApiKey},
        );
        final stRes =
            await http.get(statusUri).timeout(const Duration(seconds: 8));
        if (stRes.statusCode != 200) continue;

        final stData = json.decode(utf8.decode(stRes.bodyBytes));
        if (stData is! Map) continue;

        final dosyaUrl = stData['dosya_url']?.toString();
        final durum = stData['durum']?.toString();

        if (durum == 'bitti' && dosyaUrl != null && dosyaUrl.isNotEmpty) {
          final fileName = dosyaUrl.split('/').last;
          final encodedUri = Uri(
            scheme: 'https',
            host: 'mp3-apisi.onrender.com',
            path: '/api/v1/file/$fileName',
            queryParameters: {'key': ApiConfig.mp3ApiKey},
          ).toString();

          _resolvedMp3Cache[cacheKey] = encodedUri;
          _resolvedMp3Cache[song.id] = encodedUri;
          debugPrint('mp3-apisi: ready → $encodedUri');
          return encodedUri;
        }

        if (durum == 'hata') {
          debugPrint('mp3-apisi: job errored – ${stData['hata']}');
          return null;
        }

        debugPrint('mp3-apisi: polling $i – durum=$durum ${stData['yuzde']}%');
      }
    } catch (e) {
      debugPrint('mp3-apisi error: $e');
    }
    return null;
  }

  Future<String?> _findVideoIdForSong(String artist, String title) async {
    for (final instance in _invidiousInstances) {
      try {
        final uri = Uri.parse(
          '$instance/api/v1/search?q=${Uri.encodeComponent('$artist $title')}&type=video',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          if (data is List && data.isNotEmpty) {
            final first = data.first;
            if (first is Map && first['videoId'] != null) {
              return first['videoId'].toString();
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  //  Canvas + kapak
  // ─────────────────────────────────────────────────────────────

  /// Tek şarkı için Spotify Canvas + yüksek çözünürlüklü kapak.
  /// Sonuçlar oturum boyunca cache'lenir.
  Future<SongArtwork> fetchSpotifyCanvas({
    String? trackId,
    String? query,
  }) {
    final hasId = trackId != null && trackId.isNotEmpty;
    final hasQuery = query != null && query.isNotEmpty;
    if (!hasId && !hasQuery) {
      return Future.value((canvasUrl: null, coverUrl: null));
    }

    final cacheKey = hasId ? 'id:$trackId' : 'q:$query';
    final cached = _artworkCache[cacheKey];
    if (cached != null) return Future.value(cached);

    final inFlight = _artworkInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = _fetchArtwork(cacheKey, trackId: trackId, query: query);
    _artworkInFlight[cacheKey] = future;
    return future.whenComplete(() {
      _artworkInFlight.remove(cacheKey);
    });
  }

  Future<SongArtwork> _fetchArtwork(
    String cacheKey, {
    String? trackId,
    String? query,
  }) async {
    final params = <String, String>{};
    if (trackId != null && trackId.isNotEmpty) params['trackId'] = trackId;
    if (query != null && query.isNotEmpty) params['query'] = query;

    final res = await _serverGet(
      '/api/canvas?${Uri(queryParameters: params).query}',
      timeout: const Duration(seconds: 12),
    );

    if (res != null) {
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          final root = decoded['data'] is Map
              ? Map<String, dynamic>.from(decoded['data'] as Map)
              : decoded;

          String? canvasUrl;
          final list = decoded['canvasesList'] ?? root['canvasesList'];
          if (list is List && list.isNotEmpty && list.first is Map) {
            final url = (list.first as Map)['canvasUrl']?.toString();
            if (url != null && url.isNotEmpty) canvasUrl = url;
          }

          final coverRaw = decoded['coverUrl']?.toString() ??
              root['coverUrl']?.toString();
          final coverUrl = (coverRaw != null && coverRaw.isNotEmpty) ? coverRaw : null;

          if (canvasUrl != null || coverUrl != null) {
            final result = (canvasUrl: canvasUrl, coverUrl: coverUrl);
            _artworkCache[cacheKey] = result;
            return result;
          }
        }
      } catch (error) {
        debugPrint('Canvas cevabı okunamadı: $error');
      }
    }

    const miss = (canvasUrl: null, coverUrl: null);
    // Sunucuya hiç ulaşılamadıysa negatif cache'leme: sunucu sonradan
    // ayağa kalktığında tekrar denenebilsin.
    if (res != null) _artworkCache[cacheKey] = miss;
    return miss;
  }

  /// Ana ekrandaki liste için TEK istekte canvas + kapak çözümleme.
  /// Sunucu yoksa boş döner; çağıran taraf tek tek denemeye devam eder.
  Future<Map<String, SongArtwork>> fetchSpotifyCanvasBatch(
    List<Song> songs,
  ) async {
    if (songs.isEmpty) return {};

    final items = songs
        .map((song) => {
              'id': song.id,
              if (song.spotifyTrackId != null &&
                  song.spotifyTrackId!.isNotEmpty)
                'trackId': song.spotifyTrackId,
              'query': '${song.artist} ${song.title}',
              'artist': song.artist,
              'title': song.title,
            })
        .toList();

    final res = await _serverPostJson(
      '/api/canvas/batch',
      {'items': items},
      timeout: const Duration(seconds: 15),
    );
    if (res == null) return {};

    final result = <String, SongArtwork>{};
    try {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      final list = decoded is Map ? decoded['results'] : null;
      if (list is! List) return {};

      for (final entry in list) {
        if (entry is! Map) continue;
        final id = entry['id']?.toString();
        if (id == null || id.isEmpty) continue;

        final canvasRaw = entry['canvasUrl']?.toString();
        final coverRaw = entry['coverUrl']?.toString();
        final artwork = (
          canvasUrl: (canvasRaw != null && canvasRaw.isNotEmpty) ? canvasRaw : null,
          coverUrl: (coverRaw != null && coverRaw.isNotEmpty) ? coverRaw : null,
        );
        if (artwork.canvasUrl == null && artwork.coverUrl == null) continue;

        result[id] = artwork;

        // Tekli çağrılar da aynı sonucu bulsun
        final trackId = entry['trackId']?.toString();
        if (trackId != null && trackId.isNotEmpty) {
          _artworkCache['id:$trackId'] = artwork;
        }
        Song? song;
        for (final candidate in songs) {
          if (candidate.id == id) {
            song = candidate;
            break;
          }
        }
        if (song != null) {
          _artworkCache['q:${song.artist} ${song.title}'] = artwork;
        }
      }
    } catch (error) {
      debugPrint('Batch canvas cevabı okunamadı: $error');
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────
  //  İndirme
  // ─────────────────────────────────────────────────────────────

  /// MP3'ü indirir. IO platformlarında dosya yolunu döner,
  /// web'de tarayıcı indirmesini başlatır (localPath null).
  Future<({bool ok, String? localPath})> downloadSong(Song song) async {
    if (_localFilePaths.containsKey(song.id)) {
      final cached = _localFilePaths[song.id]!;
      return (ok: true, localPath: cached);
    }

    String? mp3Url;

    if (song.audioUrl != null &&
        song.audioUrl!.isNotEmpty &&
        !song.audioUrl!.startsWith('file://') &&
        !song.audioUrl!.startsWith('/')) {
      mp3Url = song.audioUrl;
    } else {
      final fresh = song.copyWith(audioUrl: null);
      final resolved = await fetchMp3Stream(fresh);
      if (resolved.audioUrl != null &&
          resolved.audioUrl!.isNotEmpty &&
          !resolved.audioUrl!.startsWith('file://') &&
          !resolved.audioUrl!.startsWith('/')) {
        mp3Url = resolved.audioUrl;
      }
    }

    if (mp3Url == null || mp3Url.isEmpty) {
      debugPrint('İndirme başarısız: MP3 URL bulunamadı → ${song.title}');
      return (ok: false, localPath: null);
    }

    final safeId = song.id.replaceAll(RegExp(r'[^\w-]'), '_');
    final result = await streamUrlToLocalFile(url: mp3Url, safeId: safeId);

    if (result.ok && result.localPath != null) {
      _localFilePaths[song.id] = result.localPath!;
      debugPrint('✓ Dosya kaydedildi: ${result.localPath}');
    }
    return result;
  }
}
