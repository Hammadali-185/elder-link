import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/music_track.dart';
import 'api_service.dart';

/// Single [AudioPlayer] for the whole app — only one track at a time.
class MusicPlayerService extends ChangeNotifier {
  MusicPlayerService._();
  static final MusicPlayerService instance = MusicPlayerService._();

  /// When true (watch app only), posts playback metadata to MongoDB via [ApiService].
  static bool reportSessionsToBackend = false;

  final AudioPlayer _player = AudioPlayer();
  List<MusicTrack> _playlist = const [];
  int _index = 0;
  String? _lastError;
  bool _inited = false;
  int _playbackGen = 0;

  AudioPlayer get player => _player;

  List<MusicTrack> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _index;
  MusicTrack? get currentTrack =>
      _playlist.isEmpty ? null : _playlist[_index.clamp(0, _playlist.length - 1)];
  String? get lastError => _lastError;

  Future<void> ensureInitialized() async {
    if (_inited) return;
    _inited = true;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MusicPlayerService: audio session config failed: $e');
      }
    }

    _player.playbackEventStream.listen(
      (_) => notifyListeners(),
      onError: (Object e, StackTrace _) {
        _lastError = e.toString();
        notifyListeners();
      },
    );
    _player.playerStateStream.listen((state) {
      notifyListeners();
      if (!reportSessionsToBackend) return;
      if (state.processingState == ProcessingState.completed && !state.playing) {
        ApiService.endMusicSessionMeta('completed');
      }
    });
  }

  /// After a medicine alarm, re-apply media routing so the music player is not stuck on alarm usage.
  Future<void> restoreMediaAudioSession() async {
    if (!_inited) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('MusicPlayerService: restoreMediaAudioSession failed: $e');
      }
    }
  }

  Future<void> playPlaylist(List<MusicTrack> tracks, int index) async {
    await ensureInitialized();
    _lastError = null;
    if (tracks.isEmpty) {
      _playlist = [];
      await _player.stop();
      if (reportSessionsToBackend) {
        await ApiService.endMusicSessionMeta('stopped');
      }
      notifyListeners();
      return;
    }
    _playlist = List<MusicTrack>.from(tracks);
    await _loadAndPlayIndex(index);
  }

  Future<void> _loadAndPlayIndex(int rawIndex) async {
    if (_playlist.isEmpty) return;
    _playbackGen++;
    final gen = _playbackGen;
    _index = rawIndex.clamp(0, _playlist.length - 1);
    final track = _playlist[_index];
    _lastError = null;
    notifyListeners();

    if (reportSessionsToBackend) {
      await ApiService.endMusicSessionMeta('stopped');
    }

    try {
      await _player.stop();
      if (track.isAsset) {
        await _player.setAsset(track.assetPath!);
      } else if (track.isRemote) {
        await _player.setUrl(track.audioUrl!);
      } else {
        _lastError = 'No audio source for "${track.title}"';
        notifyListeners();
        return;
      }
      await _player.play();
      if (reportSessionsToBackend &&
          gen == _playbackGen &&
          _lastError == null) {
        await ApiService.startMusicSessionMeta(
          trackId: track.id,
          title: track.title,
          artist: track.artist,
          category: track.category,
        );
      }
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    await ensureInitialized();
    try {
      if (_player.playing) {
        await _player.pause();
        if (reportSessionsToBackend) {
          await ApiService.endMusicSessionMeta('paused');
        }
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
        if (reportSessionsToBackend) {
          final t = currentTrack;
          if (t != null) {
            await ApiService.startMusicSessionMeta(
              trackId: t.id,
              title: t.title,
              artist: t.artist,
              category: t.category,
            );
          }
        }
      }
    } catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await ensureInitialized();
    try {
      await _player.stop();
      if (reportSessionsToBackend) {
        await ApiService.endMusicSessionMeta('stopped');
      }
    } catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (_playlist.isEmpty) return;
    final next = (_index + 1) % _playlist.length;
    await _loadAndPlayIndex(next);
  }

  Future<void> skipPrevious() async {
    if (_playlist.isEmpty) return;
    final prev = _index - 1 < 0 ? _playlist.length - 1 : _index - 1;
    await _loadAndPlayIndex(prev);
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}
