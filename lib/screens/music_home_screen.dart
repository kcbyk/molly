import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_toast.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_screen.dart';
import '../widgets/song_menu_sheet.dart';
import '../widgets/song_row.dart';

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({super.key});

  @override
  State<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen>
    with TickerProviderStateMixin {
  AppTab _currentTab = AppTab.discover;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearching = false;

  final Set<String> _likedSongIds = {};
  final Set<String> _downloadedSongIds = {};
  final Set<String> _downloadingSongIds = {};

  String _currentSongId = 'c9r1Vfb51X8';
  bool _isPlaying = false;
  double _progress = 0.0;
  int _currentPositionSeconds = 0;
  double _scrollRatio = 0.0;

  bool _isPlayerOpen = false;
  bool _isShuffle = false;
  bool _isRepeat = false;

  Timer? _playbackTimer;
  Timer? _toastTimer;
  String _toastMessage = '';

  late AnimationController _spinController;

  List<Song> _songs = List.from(Song.initialSongs);
  final Map<String, Song> _knownSongs = {};

  final AudioPlayerService _audioService = AudioPlayerService();
  final MusicApiService _apiService = MusicApiService();

  Color _smartPlayerColor = const Color(0xFF16161E);
  Color _smartDarkNavColor = const Color(0xFF08080C);
  String? _lastExtractedCoverUrl;

  Future<void> _updateSmartColors(Song song) async {
    final url = song.coverUrl;
    if (url == null || url.isEmpty || url == _lastExtractedCoverUrl) return;
    _lastExtractedCoverUrl = url;

    // Unit test check
    if (WidgetsBinding.instance is! WidgetsFlutterBinding) {
      if (mounted) {
        final pColor = Color.lerp(song.color1, const Color(0xFF101016), 0.70)!;
        final nColor = Color.lerp(pColor, const Color(0xFF06060A), 0.60)!;
        setState(() {
          _smartPlayerColor = pColor;
          _smartDarkNavColor = nColor;
        });
      }
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(80, 80),
        maximumColorCount: 6,
      );
      if (!mounted) return;
      final dominant = palette.dominantColor?.color ?? palette.vibrantColor?.color ?? song.color1;

      // Oynatıcı rengi: Kapaktaki ana renkten türetilen zengin koyu ton
      final pColor = Color.lerp(dominant, const Color(0xFF101016), 0.70)!;

      // Alt bar rengi: Oynatıcıyla birebir AYNI rengin daha koyu ve derin tonu
      final nColor = Color.lerp(pColor, const Color(0xFF06060A), 0.60)!;

      setState(() {
        _smartPlayerColor = pColor;
        _smartDarkNavColor = nColor;
      });
    } catch (_) {
      if (mounted) {
        final pColor = Color.lerp(song.color1, const Color(0xFF101016), 0.70)!;
        final nColor = Color.lerp(pColor, const Color(0xFF06060A), 0.60)!;
        setState(() {
          _smartPlayerColor = pColor;
          _smartDarkNavColor = nColor;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    for (final s in Song.initialSongs) {
      _knownSongs[s.id] = s;
    }

    _searchController.addListener(_onSearchChanged);

    // Audio service listeners
    _audioService.onPositionChanged.listen((duration) {
      if (_isPlaying && mounted) {
        final curSong = _getCurrentSong();
        setState(() {
          _currentPositionSeconds = duration.inSeconds;
          if (curSong.durationSeconds > 0) {
            _progress = (_currentPositionSeconds / curSong.durationSeconds).clamp(0.0, 1.0);
          }
        });
      }
    });

    _audioService.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed && mounted) {
        if (_isRepeat) {
          _seekTo(0);
          _audioService.resume();
        } else {
          _nextSong();
        }
      }
    });

    // Pre-fetch Spotify covers for all initial songs on startup
    _prefetchSpotifyCovers();
    _updateSmartColors(_getCurrentSong());
  }

  /// Uygulama açılınca tüm şarkılar için Spotify 640x640 kapak + canvas pre-fetch
  Future<void> _prefetchSpotifyCovers() async {
    if (WidgetsBinding.instance is! WidgetsFlutterBinding) return;
    for (final song in Song.initialSongs) {
      // Canvas URL zaten varsa cover fetch yap, yoksa ikisini birden al
      final needsCanvas = song.canvasUrl == null || song.canvasUrl!.isEmpty;
      // cover zaten Spotify CDN'den geliyorsa atla (i.scdn.co)
      final needsCover = song.coverUrl == null ||
          song.coverUrl!.isEmpty ||
          !song.coverUrl!.contains('scdn.co');

      if (!needsCover && !needsCanvas) continue;

      try {
        final result = await _apiService.fetchSpotifyCanvas(
          trackId: song.spotifyTrackId,
          query: (song.spotifyTrackId == null || song.spotifyTrackId!.isEmpty)
              ? '${song.artist} ${song.title}'
              : null,
        );
        if (!mounted) return;

        final updated = _knownSongs[song.id] ?? song;
        final newSong = updated.copyWith(
          coverUrl: (needsCover && result.coverUrl != null)
              ? result.coverUrl
              : updated.coverUrl,
          canvasUrl: (needsCanvas && result.canvasUrl != null)
              ? result.canvasUrl
              : updated.canvasUrl,
        );

        setState(() {
          _knownSongs[song.id] = newSong;
          final idx = _songs.indexWhere((s) => s.id == song.id);
          if (idx != -1) _songs[idx] = newSong;
        });
      } catch (_) {}
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        setState(() {
          _songs = List.from(Song.initialSongs);
          _isSearching = false;
        });
      } else {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    final results = await _apiService.search(query);
    if (!mounted) return;

    for (final s in results) {
      _knownSongs[s.id] = s;
    }

    setState(() {
      _songs = results;
      _isSearching = false;
    });

    // Pre-fetch high-res Spotify covers & canvas for top search results in parallel
    for (int i = 0; i < math.min(results.length, 6); i++) {
      final s = results[i];
      _apiService.fetchSpotifyCanvas(
        query: '${s.artist} ${s.title}',
      ).then((res) {
        if (!mounted) return;
        if (res.coverUrl != null || res.canvasUrl != null) {
          final cur = _knownSongs[s.id] ?? s;
          final updated = cur.copyWith(
            coverUrl: res.coverUrl ?? cur.coverUrl,
            canvasUrl: res.canvasUrl ?? cur.canvasUrl,
          );
          setState(() {
            _knownSongs[s.id] = updated;
            final idx = _songs.indexWhere((item) => item.id == s.id);
            if (idx != -1) _songs[idx] = updated;
          });
        }
      });
    }
  }

  Song _getCurrentSong() {
    return _knownSongs[_currentSongId] ??
        _songs.firstWhere(
          (s) => s.id == _currentSongId,
          orElse: () => _songs.isNotEmpty ? _songs.first : Song.initialSongs.first,
        );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _playbackTimer?.cancel();
    _toastTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _toastMessage = '';
        });
      }
    });
  }

  Future<void> _togglePlay() async {
    final curSong = _getCurrentSong();
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _spinController.repeat();
      if (_audioService.currentUrl == curSong.audioUrl &&
          curSong.audioUrl != null &&
          curSong.audioUrl!.isNotEmpty &&
          _audioService.player.state == PlayerState.paused) {
        _audioService.resume();
      } else {
        await _playSong(curSong);
      }
    } else {
      _spinController.stop();
      _playbackTimer?.cancel();
      _audioService.pause();
    }
  }

  Future<void> _playSong(Song song) async {
    _updateSmartColors(song);
    setState(() {
      _currentSongId = song.id;
      _knownSongs[song.id] = song;
      _isPlaying = true;
      _currentPositionSeconds = 0;
      _progress = 0.0;
      _spinController.repeat();
    });

    Song resolved = song;
    if (resolved.audioUrl == null || resolved.audioUrl!.isEmpty) {
      resolved = await _apiService.fetchMp3Stream(song);
      if (!mounted) return;
      if (_currentSongId == song.id) {
        setState(() {
          _knownSongs[song.id] = resolved;
          final idx = _songs.indexWhere((s) => s.id == song.id);
          if (idx != -1) {
            _songs[idx] = resolved;
          }
        });
      }
    }

    if (resolved.audioUrl != null && resolved.audioUrl!.isNotEmpty) {
      if (_currentSongId == song.id && _isPlaying) {
        _audioService.play(resolved.audioUrl, forceFromBeginning: true);
      }
    } else {
      _startFallbackPlaybackTimer();
    }

    // Try fetching Spotify Canvas + high-res cover if not already cached
    final needsCover = resolved.coverUrl == null || !resolved.coverUrl!.contains('scdn.co');
    final needsCanvas = resolved.canvasUrl == null || resolved.canvasUrl!.isEmpty;
    if (needsCover || needsCanvas) {
      final query = '${resolved.artist} ${resolved.title}';
      _apiService.fetchSpotifyCanvas(
        trackId: resolved.spotifyTrackId,
        query: (resolved.spotifyTrackId == null || resolved.spotifyTrackId!.isEmpty) ? query : null,
      ).then((result) {
        if (mounted && _currentSongId == song.id) {
          final current = _getCurrentSong();
          // Apply canvas URL and/or Spotify high-res cover if available
          final updated = current.copyWith(
            canvasUrl: result.canvasUrl ?? current.canvasUrl,
            coverUrl: result.coverUrl ?? current.coverUrl,
          );
          setState(() {
            _knownSongs[song.id] = updated;
            final idx = _songs.indexWhere((s) => s.id == song.id);
            if (idx != -1) _songs[idx] = updated;
          });
          _updateSmartColors(updated);
        }
      });
    }
  }

  void _startFallbackPlaybackTimer() {
    _playbackTimer?.cancel();
    final curSong = _getCurrentSong();
    // Only use timer fallback if no real audio stream exists
    if (curSong.audioUrl != null && curSong.audioUrl!.isNotEmpty) {
      return;
    }

    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlaying || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentPositionSeconds++;
        if (_currentPositionSeconds >= curSong.durationSeconds) {
          if (_isRepeat) {
            _currentPositionSeconds = 0;
          } else {
            _stepSong(1);
            return;
          }
        }
        _progress = (_currentPositionSeconds / curSong.durationSeconds).clamp(0.0, 1.0);
      });
    });
  }

  void _stepSong(int direction) {
    if (_songs.isEmpty) return;
    final currentIndex = _songs.indexWhere((s) => s.id == _currentSongId);
    int nextIndex;
    if (_isShuffle && _songs.length > 1) {
      final random = math.Random();
      do {
        nextIndex = random.nextInt(_songs.length);
      } while (nextIndex == currentIndex);
    } else {
      nextIndex = (currentIndex + direction + _songs.length) % _songs.length;
    }
    _playSong(_songs[nextIndex]);
  }

  void _previousSong() {
    if (_currentPositionSeconds > 3) {
      _seekTo(0);
    } else {
      _stepSong(-1);
    }
  }

  void _nextSong() {
    _stepSong(1);
  }

  void _seekTo(double seconds) {
    final curSong = _getCurrentSong();
    setState(() {
      _currentPositionSeconds = seconds.toInt();
      _progress = (_currentPositionSeconds / curSong.durationSeconds).clamp(0.0, 1.0);
    });
    _audioService.seek(Duration(seconds: seconds.toInt()));
  }

  void _openNowPlaying() {
    setState(() {
      _isPlayerOpen = true;
    });
  }

  void _closeNowPlaying() {
    setState(() {
      _isPlayerOpen = false;
    });
  }

  void _openLibraryFromPlayer() {
    setState(() {
      _isPlayerOpen = false;
      _currentTab = AppTab.library;
      _scrollRatio = 0.0;
    });
    _showToast('Kütüphane açıldı');
  }

  void _toggleLike(String songId) {
    setState(() {
      if (_likedSongIds.contains(songId)) {
        _likedSongIds.remove(songId);
        _showToast('Beğenilenlerden çıkarıldı');
      } else {
        _likedSongIds.add(songId);
        _showToast('Beğenilenlere eklendi');
      }
    });
  }

  void _toggleDownload(String songId) {
    // Her zaman en güncel song nesnesini al
    final song = _knownSongs[songId] ??
        _songs.firstWhere((s) => s.id == songId, orElse: () => _songs.first);

    if (_downloadedSongIds.contains(songId)) {
      // İndirmeyi kaldır
      setState(() {
        _downloadedSongIds.remove(songId);
        final updated = song.copyWith(audioUrl: null);
        _knownSongs[songId] = updated;
        final idx = _songs.indexWhere((s) => s.id == songId);
        if (idx != -1) _songs[idx] = updated;
      });
      _showToast('İndirme kaldırıldı');
    } else if (!_downloadingSongIds.contains(songId)) {
      setState(() => _downloadingSongIds.add(songId));
      _showToast('İndiriliyor...');

      // En güncel şarkı nesnesini kullan (videoId içeriyor olabilir)
      final songToDownload = _knownSongs[songId] ?? song;
      _apiService.downloadSong(songToDownload).then((result) {
        if (!mounted) return;
        setState(() => _downloadingSongIds.remove(songId));
        if (result.ok && result.localPath != null) {
          setState(() {
            _downloadedSongIds.add(songId);
            final updated = (_knownSongs[songId] ?? song)
                .copyWith(audioUrl: result.localPath);
            _knownSongs[songId] = updated;
            final idx = _songs.indexWhere((s) => s.id == songId);
            if (idx != -1) _songs[idx] = updated;
          });
          _showToast('✓ İndirildi');
        } else {
          _showToast('İndirme başarısız – API hatası');
        }
      }).catchError((e) {
        if (!mounted) return;
        setState(() => _downloadingSongIds.remove(songId));
        _showToast('İndirme başarısız');
        debugPrint('İndirme catch hatası: $e');
      });
    }
  }

  void _openSongMenu(Song song) {
    SongMenuSheet.show(
      context: context,
      song: song,
      isLiked: _likedSongIds.contains(song.id),
      isDownloaded: _downloadedSongIds.contains(song.id),
      isDownloading: _downloadingSongIds.contains(song.id),
      onShare: () {
        Clipboard.setData(ClipboardData(text: 'https://music.solenz.com/track/${song.id}'));
        _showToast('Bağlantı kopyalandı');
      },
      onDownload: () => _toggleDownload(song.id),
      onToggleLike: () => _toggleLike(song.id),
    );
  }

  List<Song> _getFilteredSongs() {
    switch (_currentTab) {
      case AppTab.discover:
        return _songs;

      case AppTab.library:
        return _downloadedSongIds
            .map((id) => _knownSongs[id] ?? _songs.firstWhere((s) => s.id == id, orElse: () => Song.initialSongs.first))
            .toSet()
            .toList();

      case AppTab.liked:
        return _likedSongIds
            .map((id) => _knownSongs[id] ?? _songs.firstWhere((s) => s.id == id, orElse: () => Song.initialSongs.first))
            .toSet()
            .toList();
    }
  }

  String _getTitle() {
    switch (_currentTab) {
      case AppTab.discover:
        return 'Keşfet';
      case AppTab.library:
        return 'Kütüphane';
      case AppTab.liked:
        return 'Beğenilen';
    }
  }

  String _getSubtitle(int count) {
    switch (_currentTab) {
      case AppTab.discover:
        return 'Bugün ne dinlemek istersin?';
      case AppTab.library:
        return 'İndirdiğin şarkılar · $count';
      case AppTab.liked:
        return 'Kalbini kazananlar · $count';
    }
  }

  String _getEmptyText() {
    switch (_currentTab) {
      case AppTab.discover:
        return 'Sonuç bulunamadı. Başka bir şarkı veya sanatçı dene.';
      case AppTab.library:
        return 'Henüz indirilmiş şarkı yok. Keşfet’ten bir şarkı indir.';
      case AppTab.liked:
        return 'Henüz beğendiğin şarkı yok.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _getCurrentSong();
    final filteredSongs = _getFilteredSongs();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _buildPhoneContent(
          currentSong: currentSong,
          filteredSongs: filteredSongs,
        ),
      ),
    );
  }

  Widget _buildPhoneContent({
    required Song currentSong,
    required List<Song> filteredSongs,
  }) {
    final headerSpacerHeight = _currentTab == AppTab.discover ? 170.0 : 104.0;

    final currentIndex = _songs.indexWhere((s) => s.id == _currentSongId);
    final nextSong = _songs.isNotEmpty
        ? _songs[(currentIndex + 1) % _songs.length]
        : currentSong;

    return Stack(
      children: [
        // 1. Main Scrollable List
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification ||
                  notification is OverscrollNotification) {
                final pixels = notification.metrics.pixels;
                final newRatio = (pixels / 30.0).clamp(0.0, 1.0);
                if ((newRatio - _scrollRatio).abs() > 0.01) {
                  setState(() {
                    _scrollRatio = newRatio;
                  });
                }
              }
              return false;
            },
            child: CustomScrollView(
              key: ValueKey('scroll_${_currentTab.name}'),
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: headerSpacerHeight),
                ),

                if (filteredSongs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                        child: Text(
                          _getEmptyText(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 180),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = filteredSongs[index];
                          final isCur = song.id == _currentSongId;
                          final isLiked = _likedSongIds.contains(song.id);
                          final isDownloaded = _downloadedSongIds.contains(song.id);
                          final isDownloading = _downloadingSongIds.contains(song.id);

                          return SongRow(
                            key: ValueKey('${song.id}_${_currentTab.name}'),
                            song: song,
                            isCurrent: isCur,
                            isLiked: isLiked,
                            isDownloaded: isDownloaded,
                            isDownloading: isDownloading,
                            isLibraryTab: _currentTab == AppTab.library,
                            onPlay: () => _playSong(song),
                            onToggleLike: () => _toggleLike(song.id),
                            onToggleDownload: () => _toggleDownload(song.id),
                            onOpenMenu: () => _openSongMenu(song),
                          );
                        },
                        childCount: filteredSongs.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 2. Bottom Soft Black Shadow (Songs scroll underneath and remain visible)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 190,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.40, 0.70, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 3. Pinned Solid Header with Search Bar & Scroll Shadow
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.background,
                child: _buildHeaderContent(filteredSongs.length),
              ),

              // Siyah Yumuşak Gölge (Kaydırdıkça belirginleşen dinamik gölge efekti)
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.70 * _scrollRatio),
                        Colors.black.withValues(alpha: 0.25 * _scrollRatio),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 4. Mini Player (sadece şarkı çalındıktan sonra görünür)
        if (_isPlaying || _currentPositionSeconds > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: MiniPlayer(
            currentSong: currentSong,
            isPlaying: _isPlaying,
            progress: _progress,
            spinController: _spinController,
            onTogglePlay: _togglePlay,
            onTap: _openNowPlaying,
            smartBgColor: _smartPlayerColor,
            onSeekRatio: (ratio) {
              final dur = currentSong.durationSeconds;
              if (dur > 0) {
                _seekTo(ratio * dur);
              }
            },
          ),
        ),

        // 5. Bottom Navigation Bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MusicBottomNavBar(
            currentTab: _currentTab,
            onTabSelected: (tab) {
              setState(() {
                _currentTab = tab;
                _scrollRatio = 0.0;
              });
            },
            smartBgColor: _smartDarkNavColor,
          ),
        ),

        // 6. Full Screen Now Playing Player
        AnimatedPositioned(
          duration: const Duration(milliseconds: 380),
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          top: _isPlayerOpen ? 0 : MediaQuery.of(context).size.height,
          left: 0,
          right: 0,
          bottom: _isPlayerOpen ? 0 : -MediaQuery.of(context).size.height,
          child: NowPlayingScreen(
            song: currentSong,
            nextSong: nextSong,
            contextTitle: _getTitle(),
            isPlaying: _isPlaying,
            currentPositionSeconds: _currentPositionSeconds,
            isLiked: _likedSongIds.contains(currentSong.id),
            isShuffle: _isShuffle,
            isRepeat: _isRepeat,
            spinController: _spinController,
            onClose: _closeNowPlaying,
            onTogglePlay: _togglePlay,
            onPrevious: _previousSong,
            onNext: _nextSong,
            onToggleLike: () => _toggleLike(currentSong.id),
            onToggleShuffle: () {
              setState(() {
                _isShuffle = !_isShuffle;
                _showToast(_isShuffle ? 'Karıştırma açık' : 'Karıştırma kapalı');
              });
            },
            onToggleRepeat: () {
              setState(() {
                _isRepeat = !_isRepeat;
                _showToast(_isRepeat ? 'Tekrar açık' : 'Tekrar kapalı');
              });
            },
            onSeek: _seekTo,
            onPlayNext: () => _playSong(nextSong),
            onOpenMenu: () => _openSongMenu(currentSong),
            onOpenLibrary: _openLibraryFromPlayer,
          ),
        ),

        // 7. Toast Message
        if (_toastMessage.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: _isPlayerOpen ? 120 : 176,
            child: Center(
              child: AppToast(message: _toastMessage),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderContent(int songCount) {
    return Container(
      padding: const EdgeInsets.only(
        left: 22,
        right: 22,
        top: 16,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getTitle(),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getSubtitle(songCount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          if (_currentTab == AppTab.discover) ...[
            const SizedBox(height: 14),
            // Search Bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  AppIcons.search(
                    size: 19,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Şarkı veya sanatçı ara',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                      },
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
