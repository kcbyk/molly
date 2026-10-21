import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/music_api_service.dart';
import '../services/palette_cache.dart';
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
  // Now Playing alt ağacı yalnızca açıkken/animasyon sırasında kurulur.
  bool _playerLayerVisible = false;
  bool _isShuffle = false;
  bool _isRepeat = false;

  static const List<AppTab> _tabs = [
    AppTab.discover,
    AppTab.library,
    AppTab.liked,
  ];
  late final PageController _pageController;

  Timer? _playbackTimer;
  Timer? _toastTimer;
  Timer? _playerHideTimer;
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
      _applySmartColors(song, song.color1);
      return;
    }

    // Now Playing aynı kapağı analiz ettiyse cache'ten anında gelir.
    final cached = PaletteCache.peek(url);
    if (cached?.dominant != null) {
      _applySmartColors(song, cached!.dominant);
      return;
    }

    final palette = await PaletteCache.load(url);
    if (!mounted) return;
    _applySmartColors(song, palette?.dominant ?? song.color1);
  }

  void _applySmartColors(Song song, Color? dominantColor) {
    if (!mounted) return;
    final dominant = dominantColor ?? song.color1;

    // Oynatıcı rengi: Kapaktaki ana renkten türetilen zengin koyu ton
    final pColor = Color.lerp(dominant, const Color(0xFF101016), 0.70)!;

    // Alt bar rengi: Oynatıcıyla birebir AYNI rengin daha koyu ve derin tonu
    final nColor = Color.lerp(pColor, const Color(0xFF06060A), 0.60)!;

    setState(() {
      _smartPlayerColor = pColor;
      _smartDarkNavColor = nColor;
    });
  }

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _pageController = PageController(initialPage: _tabs.indexOf(_currentTab));

    for (final s in Song.initialSongs) {
      _knownSongs[s.id] = s;
    }

    _searchController.addListener(_onSearchChanged);

    // Audio service listeners
    _audioService.onPositionChanged.listen((duration) {
      if (!_isPlaying || !mounted) return;
      // audioplayers saniyede birkaç kez haber veriyor; aynı saniye içinde
      // tekrar çizmeye gerek yok (düşük donanımda hissedilir fark).
      final seconds = duration.inSeconds;
      if (seconds == _currentPositionSeconds) return;
      final curSong = _getCurrentSong();
      setState(() {
        _currentPositionSeconds = seconds;
        if (curSong.durationSeconds > 0) {
          _progress = (_currentPositionSeconds / curSong.durationSeconds).clamp(0.0, 1.0);
        }
      });
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

    // Sunucuyu erkenden yokla (UI beklemez)
    _apiService.warmUp();

    // Pre-fetch Spotify covers for all initial songs on startup
    _prefetchSpotifyCovers();
    _updateSmartColors(_getCurrentSong());
  }

  bool _needsArtwork(Song song) {
    final needsCanvas = song.canvasUrl == null || song.canvasUrl!.isEmpty;
    // cover zaten Spotify CDN'den geliyorsa atla (i.scdn.co)
    final needsCover = song.coverUrl == null ||
        song.coverUrl!.isEmpty ||
        !song.coverUrl!.contains('scdn.co');
    return needsCover || needsCanvas;
  }

  /// Uygulama açılınca eksik kapak/canvas'ları TEK istekle çözer.
  Future<void> _prefetchSpotifyCovers() async {
    if (WidgetsBinding.instance is! WidgetsFlutterBinding) return;

    final pending = Song.initialSongs.where(_needsArtwork).toList();
    if (pending.isEmpty) return;

    final batch = await _apiService.fetchSpotifyCanvasBatch(pending);
    if (!mounted) return;

    if (batch.isNotEmpty) {
      setState(() {
        batch.forEach((id, artwork) => _applySongArtwork(id, artwork));
      });
      return;
    }

    // Toplu istek başarısız olduysa tek tek 8 şarkı denemek yerine
    // yalnızca ilk 2'siyle sunucunun ayakta olup olmadığını yokla.
    for (final song in pending.take(2)) {
      await _prefetchArtworkFor(song);
      if (!mounted) return;
    }
  }

  Future<void> _prefetchArtworkFor(Song song) async {
    final needsCanvas = song.canvasUrl == null || song.canvasUrl!.isEmpty;
    final needsCover = song.coverUrl == null ||
        song.coverUrl!.isEmpty ||
        !song.coverUrl!.contains('scdn.co');
    if (!needsCover && !needsCanvas) return;

    try {
      final result = await _apiService.fetchSpotifyCanvas(
        trackId: song.spotifyTrackId,
        query: (song.spotifyTrackId == null || song.spotifyTrackId!.isEmpty)
            ? '${song.artist} ${song.title}'
            : null,
      );
      if (!mounted) return;
      setState(() {
        _applySongArtwork(
          song.id,
          (
            canvasUrl: result.canvasUrl,
            coverUrl: result.coverUrl,
          ),
        );
      });
    } catch (_) {}
  }

  void _applySongArtwork(String id, SongArtwork artwork) {
    final base = _knownSongs[id];
    if (base == null) return;
    final updated = base.copyWith(
      canvasUrl: artwork.canvasUrl,
      coverUrl: artwork.coverUrl,
    );
    _knownSongs[id] = updated;
    final idx = _songs.indexWhere((song) => song.id == id);
    if (idx != -1) _songs[idx] = updated;
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

    // İlk 6 sonuç için kapak + canvas: tek istek, sonra tekil yedek
    final topResults = results.take(6).toList();
    final batch = await _apiService.fetchSpotifyCanvasBatch(topResults);
    if (!mounted) return;

    if (batch.isNotEmpty) {
      setState(() {
        batch.forEach((id, artwork) => _applySongArtwork(id, artwork));
      });
      return;
    }

    for (final s in topResults) {
      _apiService.fetchSpotifyCanvas(
        query: '${s.artist} ${s.title}',
      ).then((res) {
        if (!mounted) return;
        if (res.coverUrl != null || res.canvasUrl != null) {
          setState(() {
            _applySongArtwork(
              s.id,
              (canvasUrl: res.canvasUrl, coverUrl: res.coverUrl),
            );
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
    _pageController.dispose();
    _playbackTimer?.cancel();
    _toastTimer?.cancel();
    _playerHideTimer?.cancel();
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
    _playerHideTimer?.cancel();

    if (!_playerLayerVisible) {
      // Önce ekran dışında kur, sonraki karede yukarı kaydır.
      setState(() {
        _playerLayerVisible = true;
        _isPlayerOpen = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isPlayerOpen = true;
        });
      });
      return;
    }

    setState(() {
      _isPlayerOpen = true;
    });
  }

  void _closeNowPlaying() {
    if (!_isPlayerOpen) return;
    setState(() {
      _isPlayerOpen = false;
    });
    // Kapanış animasyonu bitince ağır Now Playing ağacını (ve canvas
    // videosunu) tamamen kaldır.
    _playerHideTimer?.cancel();
    _playerHideTimer = Timer(const Duration(milliseconds: 420), () {
      if (mounted && !_isPlayerOpen) {
        setState(() {
          _playerLayerVisible = false;
        });
      }
    });
  }

  void _selectTab(AppTab tab, {bool animate = true}) {
    final index = _tabs.indexOf(tab);
    if (index == -1) return;

    final changed = _currentTab != tab;
    setState(() {
      _currentTab = tab;
      _scrollRatio = 0.0;
    });

    if (_pageController.hasClients) {
      if (animate) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else if ((_pageController.page ?? 0).round() != index) {
        _pageController.jumpToPage(index);
      }
    }

    if (changed) FocusScope.of(context).unfocus();
  }

  void _openLibraryFromPlayer() {
    _playerHideTimer?.cancel();
    setState(() {
      _isPlayerOpen = false;
      _playerLayerVisible = false;
    });
    _selectTab(AppTab.library);
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
        if (result.ok) {
          setState(() {
            _downloadedSongIds.add(songId);
            if (result.localPath != null) {
              final updated = (_knownSongs[songId] ?? song)
                  .copyWith(audioUrl: result.localPath);
              _knownSongs[songId] = updated;
              final idx = _songs.indexWhere((s) => s.id == songId);
              if (idx != -1) _songs[idx] = updated;
            }
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

  List<Song> _songsForTab(AppTab tab) {
    switch (tab) {
      case AppTab.discover:
        return _songs;

      case AppTab.library:
        return _downloadedSongIds
            .map((id) => _knownSongs[id] ??
                _songs.firstWhere((s) => s.id == id,
                    orElse: () => Song.initialSongs.first))
            .toSet()
            .toList();

      case AppTab.liked:
        return _likedSongIds
            .map((id) => _knownSongs[id] ??
                _songs.firstWhere((s) => s.id == id,
                    orElse: () => Song.initialSongs.first))
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

  String _emptyTextFor(AppTab tab) {
    switch (tab) {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _buildPhoneContent(currentSong: _getCurrentSong()),
      ),
    );
  }

  Widget _buildPhoneContent({required Song currentSong}) {
    final currentIndex = _songs.indexWhere((s) => s.id == _currentSongId);
    final nextSong = _songs.isNotEmpty
        ? _songs[(currentIndex + 1) % _songs.length]
        : currentSong;
    final currentSongs = _songsForTab(_currentTab);

    return Stack(
      children: [
        // 1. Sayfalar — sağa/sola kaydırarak Keşfet ↔ Kütüphane ↔ Beğenilen
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.vertical) return false;
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
            child: PageView(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: (index) {
                final tab = _tabs[index];
                if (tab == _currentTab) return;
                setState(() {
                  _currentTab = tab;
                  _scrollRatio = 0.0;
                });
                FocusScope.of(context).unfocus();
              },
              children: _tabs
                  .map(
                    (tab) => _TabPage(
                      tab: tab,
                      songs: _songsForTab(tab),
                      currentSongId: _currentSongId,
                      likedIds: _likedSongIds,
                      downloadedIds: _downloadedSongIds,
                      downloadingIds: _downloadingSongIds,
                      headerSpacerHeight:
                          tab == AppTab.discover ? 170.0 : 104.0,
                      emptyText: _emptyTextFor(tab),
                      onPlay: (song) {
                        _playSong(song);
                      },
                      onToggleLike: _toggleLike,
                      onToggleDownload: _toggleDownload,
                      onOpenMenu: _openSongMenu,
                    ),
                  )
                  .toList(),
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
                child: _buildHeaderContent(currentSongs.length),
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
            onTabSelected: _selectTab,
            smartBgColor: _smartDarkNavColor,
          ),
        ),

        // 6. Full Screen Now Playing Player
        // Yalnızca açıkken ağaçta tutulur → kapalıyken canvas videosu
        // ve ağır kapak/palette widget'ları CPU harcamaz.
        if (_playerLayerVisible)
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
              isActive: _isPlayerOpen,
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


class _TabPage extends StatefulWidget {
  final AppTab tab;
  final List<Song> songs;
  final String currentSongId;
  final Set<String> likedIds;
  final Set<String> downloadedIds;
  final Set<String> downloadingIds;
  final double headerSpacerHeight;
  final String emptyText;
  final ValueChanged<Song> onPlay;
  final ValueChanged<String> onToggleLike;
  final ValueChanged<String> onToggleDownload;
  final ValueChanged<Song> onOpenMenu;

  const _TabPage({
    required this.tab,
    required this.songs,
    required this.currentSongId,
    required this.likedIds,
    required this.downloadedIds,
    required this.downloadingIds,
    required this.headerSpacerHeight,
    required this.emptyText,
    required this.onPlay,
    required this.onToggleLike,
    required this.onToggleDownload,
    required this.onOpenMenu,
  });

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage>
    with AutomaticKeepAliveClientMixin {
  // Sayfa değiştirilip geri dönüldüğünde scroll konumu korunur.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return CustomScrollView(
      key: PageStorageKey<String>('scroll_${widget.tab.name}'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: widget.headerSpacerHeight),
        ),
        if (widget.songs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                child: Text(
                  widget.emptyText,
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
                  final song = widget.songs[index];
                  return SongRow(
                    key: ValueKey('${song.id}_${widget.tab.name}'),
                    song: song,
                    isCurrent: song.id == widget.currentSongId,
                    isLiked: widget.likedIds.contains(song.id),
                    isDownloaded: widget.downloadedIds.contains(song.id),
                    isDownloading: widget.downloadingIds.contains(song.id),
                    isLibraryTab: widget.tab == AppTab.library,
                    onPlay: () => widget.onPlay(song),
                    onToggleLike: () => widget.onToggleLike(song.id),
                    onToggleDownload: () => widget.onToggleDownload(song.id),
                    onOpenMenu: () => widget.onOpenMenu(song),
                  );
                },
                childCount: widget.songs.length,
              ),
            ),
          ),
      ],
    );
  }
}
