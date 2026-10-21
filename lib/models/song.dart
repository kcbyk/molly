import 'package:flutter/material.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String dur;
  final int durationSeconds;
  final Color color1;
  final Color color2;
  final String? audioUrl;
  final String? coverUrl;
  final String? videoId;
  final String? canvasUrl;
  final String? spotifyTrackId;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.dur,
    required this.durationSeconds,
    required this.color1,
    required this.color2,
    this.audioUrl,
    this.coverUrl,
    this.videoId,
    this.canvasUrl,
    this.spotifyTrackId,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? dur,
    int? durationSeconds,
    Color? color1,
    Color? color2,
    String? audioUrl,
    String? coverUrl,
    String? videoId,
    String? canvasUrl,
    String? spotifyTrackId,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      dur: dur ?? this.dur,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      color1: color1 ?? this.color1,
      color2: color2 ?? this.color2,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      videoId: videoId ?? this.videoId,
      canvasUrl: canvasUrl ?? this.canvasUrl,
      spotifyTrackId: spotifyTrackId ?? this.spotifyTrackId,
    );
  }

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color1, color2],
      );

  factory Song.fromSpotify(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['spotifyTrackId']?.toString() ?? '';
    final title = (json['title'] ?? 'Bilinmeyen Şarkı').toString();
    final artist = (json['artist'] ?? 'Bilinmeyen Sanatçı').toString();
    final cover = json['coverUrl']?.toString();
    final durSec = (json['durationSeconds'] is num) ? (json['durationSeconds'] as num).toInt() : 180;

    final hash = id.hashCode.abs();
    final palette = _gradientPalettes[hash % _gradientPalettes.length];

    final m = durSec ~/ 60;
    final s = durSec % 60;
    final durFormatted = '$m:${s.toString().padLeft(2, '0')}';

    return Song(
      id: id,
      title: title,
      artist: artist,
      dur: durFormatted,
      durationSeconds: durSec,
      color1: palette[0],
      color2: palette[1],
      coverUrl: cover,
      spotifyTrackId: id,
    );
  }

  factory Song.fromYouTube(Map<String, dynamic> json) {
    final rawTitle = (json['title'] ?? json['name'] ?? 'Bilinmeyen Şarkı').toString();
    final vidId = (json['videoId'] ?? json['id'] ?? '').toString();

    // Parse clean title and artist if title has "Artist - Song" format
    String cleanTitle = rawTitle;
    String cleanArtist = (json['author'] ?? json['artist'] ?? 'Bilinmeyen Sanatçı').toString();

    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      if (parts.length >= 2) {
        cleanArtist = parts[0].trim();
        cleanTitle = parts.sublist(1).join(' - ').trim();
      }
    }
    // Remove (Official Video), [Official Audio] etc from title
    cleanTitle = cleanTitle
        .replaceAll(RegExp(r'\((Official|Clip|Video|Audio|HD|HQ|Lyrics|Remaster)[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(Official|Clip|Video|Audio|HD|HQ|Lyrics|Remaster)[^\]]*\]', caseSensitive: false), '')
        .trim();

    final durSec = int.tryParse(json['lengthSeconds']?.toString() ?? json['duration']?.toString() ?? '180') ?? 180;
    final id = vidId.isNotEmpty ? vidId : rawTitle.hashCode.toString();

    // Thumbnail extraction: prefer maxresdefault / hq720 for crystal clear HD covers
    String? cover;
    if (vidId.isNotEmpty) {
      cover = 'https://i.ytimg.com/vi/$vidId/maxresdefault.jpg';
    } else if (json['videoThumbnails'] is List && (json['videoThumbnails'] as List).isNotEmpty) {
      final thumbs = json['videoThumbnails'] as List;
      cover = thumbs.last['url']?.toString();
    } else if (json['thumbnail'] != null) {
      cover = json['thumbnail'].toString();
    }

    if (cover != null) {
      if (cover.startsWith('//')) {
        cover = 'https:$cover';
      } else if (cover.startsWith('/')) {
        cover = 'https://i.ytimg.com$cover';
      }
    }

    final hash = id.hashCode.abs();
    final palette = _gradientPalettes[hash % _gradientPalettes.length];

    final m = durSec ~/ 60;
    final s = durSec % 60;
    final durFormatted = '$m:${s.toString().padLeft(2, '0')}';

    return Song(
      id: id,
      title: cleanTitle,
      artist: cleanArtist,
      dur: durFormatted,
      durationSeconds: durSec,
      color1: palette[0],
      color2: palette[1],
      audioUrl: json['link']?.toString() ?? json['audioUrl']?.toString(),
      coverUrl: cover,
      videoId: vidId,
    );
  }

  static const List<List<Color>> _gradientPalettes = [
    [Color(0xFFFF6B8A), Color(0xFF4B2A86)],
    [Color(0xFF4BC8FF), Color(0xFF2B3A9E)],
    [Color(0xFFFF8A4B), Color(0xFFA01F3C)],
    [Color(0xFFB8F34B), Color(0xFF0F6B4E)],
    [Color(0xFF7C5CFF), Color(0xFF1B1F5E)],
    [Color(0xFFFFD24B), Color(0xFFB5471F)],
    [Color(0xFFFF6BD6), Color(0xFF6B1F8A)],
    [Color(0xFF4BFFD0), Color(0xFF1F5B8A)],
  ];

  static const List<Song> initialSongs = [
    Song(
      id: 'c9r1Vfb51X8',
      title: 'Şımarık',
      artist: 'Tarkan',
      dur: '3:11',
      durationSeconds: 191,
      color1: Color(0xFFFF6B8A),
      color2: Color(0xFF4B2A86),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b273d3d5d5dcf25a85205584c1ff',
      videoId: 'c9r1Vfb51X8',
      spotifyTrackId: '3ajYmPDtB3P7JTPQ64Dr7P',
    ),
    Song(
      id: 'dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
      dur: '3:32',
      durationSeconds: 212,
      color1: Color(0xFF4BC8FF),
      color2: Color(0xFF2B3A9E),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b27315ebbedaacef61af244262a8',
      videoId: 'dQw4w9WgXcQ',
      spotifyTrackId: '4PTG3Z6ehGkBFwjybzWkR8',
    ),
    Song(
      id: 'L_LUpnjgPso',
      title: 'Bir Derdim Var',
      artist: 'Mor ve Ötesi',
      dur: '3:45',
      durationSeconds: 225,
      color1: Color(0xFFFF8A4B),
      color2: Color(0xFFA01F3C),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b27361cd6f5ad7c69b76adbc5419',
      videoId: 'L_LUpnjgPso',
      spotifyTrackId: '5UV2oqgMXvlkOvvtK3aT7f',
    ),
    Song(
      id: 'fJ9rUzIMcZQ',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      dur: '5:55',
      durationSeconds: 355,
      color1: Color(0xFFB8F34B),
      color2: Color(0xFF0F6B4E),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b2730f0b764e930d478c16b8d2cc',
      videoId: 'fJ9rUzIMcZQ',
      spotifyTrackId: '4u7EnebtmKWzUH433cf5Qv',
      canvasUrl: 'https://canvaz.scdn.co/upload/licensor/7JGwF0zhX9oItt9901OvB5/video/15b9ca175ea54c448de4a4b6ebd96959.cnvs.mp4',
    ),
    Song(
      id: '463CkQjx2Zk1yXoBuierM9',
      title: 'Levitating',
      artist: 'Dua Lipa',
      dur: '3:23',
      durationSeconds: 203,
      color1: Color(0xFF7C5CFF),
      color2: Color(0xFF1B1F5E),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b27387bcc972503c59ab023130b4',
      videoId: 'TUVcZfQe-Kw',
      spotifyTrackId: '463CkQjx2Zk1yXoBuierM9',
      canvasUrl: 'https://canvaz.scdn.co/upload/artist/6M2wZ9GZgrQXHCFfjv46we/video/eaf44c8d42d54925a1a94768426ab361.cnvs.mp4',
    ),
    Song(
      id: 'p2zNzsPXcHs',
      title: 'Dön Bak Dünyaya',
      artist: 'Pinhâni',
      dur: '4:12',
      durationSeconds: 252,
      color1: Color(0xFFFFD24B),
      color2: Color(0xFFB5471F),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b2731ea41639cbd072f333d25003',
      videoId: 'p2zNzsPXcHs',
      spotifyTrackId: '0gyoObUS4WilJyNRs6GlDv',
    ),
    Song(
      id: 'i6CSvLvSNZ4',
      title: 'Antidepresan',
      artist: 'Mert Demir & Mabel Matiz',
      dur: '4:15',
      durationSeconds: 255,
      color1: Color(0xFFFF6BD6),
      color2: Color(0xFF6B1F8A),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b2736a4753885f8de374c6ff1240',
      videoId: 'i6CSvLvSNZ4',
      spotifyTrackId: '4OH5Cd8ZOI1eSgJSC9PYmU',
      canvasUrl: 'https://canvaz.scdn.co/upload/artist/1Zj4GtouAnxHq4qw7ooLfm/video/55c44329281e44e385737d0225e26cb8.cnvs.mp4',
    ),
    Song(
      id: 'VREnTCTeS4k',
      title: 'Aşkın Olayım',
      artist: 'Simge',
      dur: '4:11',
      durationSeconds: 251,
      color1: Color(0xFF4BFFD0),
      color2: Color(0xFF1F5B8A),
      coverUrl: 'https://i.scdn.co/image/ab67616d0000b2738ffe0967a3b236d34428b19a',
      videoId: 'VREnTCTeS4k',
      spotifyTrackId: '4o4kbDP7DMVFPwAf5D5bj9',
      canvasUrl: 'https://canvaz.scdn.co/upload/artist/4StjyzjcmZ7a9QncHVf0pu/video/be7999095884493eb26099ec2ebeefe0.cnvs.mp4',
    ),
  ];
}
