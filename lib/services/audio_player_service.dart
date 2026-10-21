import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;

  String? get currentUrl => _currentUrl;
  AudioPlayer get player => _player;

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  AudioPlayerService._internal() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> play(String? audioUrl, {bool forceFromBeginning = true}) async {
    if (audioUrl == null || audioUrl.isEmpty) {
      debugPrint('No audio URL provided, player will simulate.');
      return;
    }
    try {
      _currentUrl = audioUrl;
      await _player.stop();
      // Local file path → DeviceFileSource; remote URL → UrlSource
      final Source source = audioUrl.startsWith('file://')
          ? DeviceFileSource(audioUrl.replaceFirst('file://', ''))
          : (RegExp(r'^[A-Za-z]:\\|^/').hasMatch(audioUrl)
              ? DeviceFileSource(audioUrl)
              : UrlSource(audioUrl));
      await _player.play(source, position: Duration.zero);
      if (forceFromBeginning) {
        await _player.seek(Duration.zero);
      }
    } catch (e) {
      debugPrint('Error playing audio stream: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
