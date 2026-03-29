import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

import 'music_player_service.dart';

/// Elder-grade medicine alert: looping alarm audio + continuous vibration until [stopAlert].
/// No push/WebSocket/Firebase. Uses alarm audio attributes on Android for maximum loudness.
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  static const String alertAssetPath = 'assets/audio/alert.mp3';

  /// Strong repeating unit: wait → vibrate → pause → vibrate → pause (ms). Loops from index 0 on Android.
  static const List<int> _vibrationPattern = [0, 1000, 400, 1000, 400];

  static const List<int> _vibrationIntensities = [0, 255, 0, 255, 0];

  /// Android: repeat index into pattern; 0 = loop from start indefinitely until [Vibration.cancel].
  static const int _vibrationRepeatForever = 0;

  final AudioPlayer _player = AudioPlayer(
    handleAudioSessionActivation: false,
    handleInterruptions: true,
  );

  bool _active = false;

  static Future<void> startAlert() => instance._startAlert();

  static Future<void> stopAlert() => instance._stopAlert();

  static bool get isAlertActive => instance._active;

  Future<void> _startAlert() async {
    if (_active) return;
    _active = true;

    try {
      final music = MusicPlayerService.instance.player;
      if (music.playing) await music.pause();
    } catch (_) {}

    if (kIsWeb) {
      try {
        await _player.stop();
        await _player.seek(Duration.zero);
        await _player.setVolume(1.0);
        await _player.setLoopMode(LoopMode.one);
        await _player.setAsset(alertAssetPath);
        await _player.play();
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('AlertService (web): audio failed: $e');
        }
      }
      return;
    }

    if (!kIsWeb) {
      try {
        final has = await Vibration.hasVibrator();
        if (has == true) {
          HapticFeedback.heavyImpact();
          await Vibration.vibrate(
            pattern: _vibrationPattern,
            intensities: _vibrationIntensities,
            repeat: _vibrationRepeatForever,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('AlertService: vibration failed: $e');
        }
      }
    }

    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.alarm,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
      await session.setActive(true);

      await _player.setAndroidAudioAttributes(
        const AndroidAudioAttributes(
          usage: AndroidAudioUsage.alarm,
          contentType: AndroidAudioContentType.sonification,
        ),
      );

      await _player.stop();
      await _player.seek(Duration.zero);
      await _player.setVolume(1.0);
      await _player.setLoopMode(LoopMode.one);
      await _player.setAsset(alertAssetPath);
      await _player.play();
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AlertService: audio failed: $e');
      }
    }
  }

  Future<void> _stopAlert() async {
    if (!_active) {
      try {
        await Vibration.cancel();
      } catch (_) {}
      try {
        await _player.stop();
      } catch (_) {}
      return;
    }
    _active = false;

    try {
      await Vibration.cancel();
    } catch (_) {}

    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      await _player.setLoopMode(LoopMode.off);
    } catch (_) {}

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}

    if (!kIsWeb) {
      try {
        await MusicPlayerService.instance.restoreMediaAudioSession();
      } catch (_) {}
    }
  }
}
