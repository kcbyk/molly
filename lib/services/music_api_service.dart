import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../models/song.dart';

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._internal();
  factory MusicApiService() => _instance;
  MusicApiService._internal();

  final Map<String, String> _resolvedMp3Cache = {};
  // songId → local file path (file:/// or absolute)
  final Map<String, String> _localFilePaths = {};

  static const List<String> _invidiousInstances = [
    'https://invidious.f5.si',
    'https://invidious.protokolla.fi',
    'https://iv.melmac.space',
  ];

  /// Search for songs via Spotify official catalog first (with full square covers),
  /// falling back to YouTube / Invidious if offline.
  Future<List<Song>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return Song.initialSongs;
    }

    // 1. First, attempt Spotify official search for pristine 1:1 square artwork & metadata
    try {
      final spotifySearchUri = Uri.parse(
        'http://localhost:3000/api/search?q=${Uri.encodeComponent(cleanQuery)}&limit=15',
      );
      final spRes = await http.get(spotifySearchUri).timeout(const Duration(seconds: 4));
      if (spRes.statusCode == 200) {
        final decoded = json.decode(utf8.decode(spRes.bodyBytes));
        if (decoded is Map && decoded['results'] is List) {
          final list = (decoded['results'] as List)
              .whereType<Map<String, dynamic>>()
              .map((it) => Song.fromSpotify(it))
              .toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('Spotify local search error, falling back to Invidious: $e');
    }

    // 2. Fallback to Invidious / YouTube search
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

    // Local fallback within initial songs
    final q = cleanQuery.toLowerCase();
    return Song.initialSongs.where((s) {
      return s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q);
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // PRIMARY: mp3-apisi.onrender.com  (320kbps, hızlı, kişisel)
  // ─────────────────────────────────────────────────────────────

  /// Resolves a direct streamable/downloadable MP3 URL via mp3-apisi.
  /// Returns null if the API fails (falls back to legacy RapidAPI path).
  Future<String?> _fetchMp3ViaPersonalApi(Song song) async {
    final query = '${song.artist} ${song.title}';
    final cacheKey = 'mpapisi_${song.id}';
    if (_resolvedMp3Cache.containsKey(cacheKey)) {
      return _resolvedMp3Cache[cacheKey];
    }

    try {
      // Step 1: Start conversion job
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
      final startRes = await http.get(startUri).timeout(const Duration(seconds: 12));
      if (startRes.statusCode != 200) return null;

      final startData = json.decode(utf8.decode(startRes.bodyBytes));
      if (startData is! Map || startData['ok'] != true) return null;

      final jobId = startData['job_id']?.toString();
      if (jobId == null || jobId.isEmpty) return null;

      debugPrint('mp3-apisi: job started → $jobId for "$query"');

      // Step 2: Poll status until done (max ~35s, 1s intervals)
      for (int i = 0; i < 35; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final statusUri = Uri(
          scheme: 'https',
          host: 'mp3-apisi.onrender.com',
          path: '/api/v1/status/$jobId',
          queryParameters: {'key': ApiConfig.mp3ApiKey},
        );
        final stRes = await http.get(statusUri).timeout(const Duration(seconds: 8));
        if (stRes.statusCode != 200) continue;

        final stData = json.decode(utf8.decode(stRes.bodyBytes));
        if (stData is! Map) continue;

        final dosyaUrl = stData['dosya_url']?.toString(); // e.g. /api/v1/file/TARKAN - Şımarık.mp3
        final durum = stData['durum']?.toString();

        if (durum == 'bitti' && dosyaUrl != null && dosyaUrl.isNotEmpty) {
          // Extract just the filename from the path, then build a properly encoded URI
          final fileName = dosyaUrl.split('/').last; // e.g. "TARKAN - Şımarık.mp3"
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

  /// Resolve real MP3 streaming URL.
  /// PRIMARY: RapidAPI youtube-mp36 (3 key rotation)
  /// FALLBACK: mp3-apisi.onrender.com (personal API, 320kbps)
  Future<Song> fetchMp3Stream(Song song) async {
    // Already resolved (could be local file path or URL)?
    if (song.audioUrl != null && song.audioUrl!.isNotEmpty) return song;

    final cacheKey = song.videoId ?? song.id;
    if (_resolvedMp3Cache.containsKey(cacheKey)) {
      return song.copyWith(audioUrl: _resolvedMp3Cache[cacheKey]);
    }

    // ── 1. PRIMARY: RapidAPI youtube-mp36 ──
    String? vidId = song.videoId;
    if (vidId == null || vidId.isEmpty) {
      vidId = await _findVideoIdForSong(song.artist, song.title);
    }

    if (vidId != null && vidId.isNotEmpty) {
      final attempts = ApiConfig.apiKeys.isNotEmpty ? ApiConfig.apiKeys.length : 1;
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
              // API işliyor — 3 saniye bekle ve tekrar dene (max 3 kere)
              debugPrint('RapidAPI işliyor, bekleniyor...');
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

  /// Fetch Spotify Canvas + high-res cover art via local server
  Future<({String? canvasUrl, String? coverUrl})> fetchSpotifyCanvas(
      {String? trackId, String? query}) async {
    try {
      final Uri uri;
      if (trackId != null && trackId.isNotEmpty) {
        uri = Uri.parse('http://localhost:3000/api/canvas?trackId=$trackId');
      } else if (query != null && query.isNotEmpty) {
        uri = Uri.parse(
            'http://localhost:3000/api/canvas?query=${Uri.encodeComponent(query)}');
      } else {
        return (canvasUrl: null, coverUrl: null);
      }

      final res = await http.get(uri).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data is Map) {
          final list = data['canvasesList'];
          final canvasUrl = (list is List && list.isNotEmpty)
              ? list[0]['canvasUrl']?.toString()
              : null;
          final coverUrl = data['coverUrl']?.toString();
          return (canvasUrl: canvasUrl, coverUrl: coverUrl);
        }
      }
    } catch (_) {}
    return (canvasUrl: null, coverUrl: null);
  }

  /// Download full song MP3, save to device local storage, return local file path.
  /// Streaming download — chunk-by-chunk, no memory spike, no timeout.
  /// Library tab plays from this local file (no network request needed later).
  Future<({bool ok, String? localPath})> downloadSong(Song song) async {
    // Already downloaded to local storage?
    if (_localFilePaths.containsKey(song.id)) {
      final cached = _localFilePaths[song.id]!;
      final file = File(cached);
      if (await file.exists()) {
        debugPrint('Dosya zaten var: $cached');
        return (ok: true, localPath: cached);
      }
    }

    // ── Step 1: Get the streaming MP3 URL (RapidAPI primary) ──
    String? mp3Url;

    if (song.audioUrl != null &&
        song.audioUrl!.isNotEmpty &&
        !song.audioUrl!.startsWith('file://') &&
        !song.audioUrl!.startsWith('/')) {
      mp3Url = song.audioUrl;
    } else {
      // Resolve URL fresh — don't use cached local path
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

    // ── Step 2: Stream download — chunk by chunk ──
    final docsDir = await getApplicationDocumentsDirectory();
    final safeId = song.id.replaceAll(RegExp(r'[^\w-]'), '_');
    final filePath = '${docsDir.path}/solenz_$safeId.mp3';
    final file = File(filePath);

    try {
      debugPrint('MP3 stream indiriliyor: $mp3Url');

      final httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      final ioClient = IOClient(httpClient);

      final request = http.Request('GET', Uri.parse(mp3Url));
      final streamedResponse = await ioClient.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('İndirme HTTP hatası: ${streamedResponse.statusCode}');
        ioClient.close();
        return (ok: false, localPath: null);
      }

      // Write chunks to file
      final sink = file.openWrite();
      int totalBytes = 0;
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        totalBytes += chunk.length;
      }
      await sink.flush();
      await sink.close();
      ioClient.close();

      if (totalBytes < 10000) {
        // Dosya çok küçük — hatalı indirme
        await file.delete();
        debugPrint('İndirme hatalı: dosya çok küçük ($totalBytes bytes)');
        return (ok: false, localPath: null);
      }

      _localFilePaths[song.id] = filePath;
      debugPrint('✓ Dosya kaydedildi: $filePath ($totalBytes bytes)');
      return (ok: true, localPath: filePath);
    } catch (e) {
      debugPrint('İndirme stream hatası: $e');
      // Yarım kalan dosyayı sil
      if (await file.exists()) await file.delete();
      return (ok: false, localPath: null);
    }
  }
}
