import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameAudioController {
  GameAudioController._();

  static final GameAudioController instance = GameAudioController._();

  static const String musicKey = 'settings_music_enabled';
  static const String soundKey = 'settings_sound_enabled';
  static const String vibrationKey = 'settings_vibration_enabled';
  static const String languageKey = 'settings_language';

  static const String _buttonSound = 'assets/music/button_sound_effect.mp3';
  static const String _gameMusic = 'assets/music/music_for_game.m4a';
  static const String _transitionSound = 'assets/music/muve_sound.mp3';
  static const MethodChannel _vibrationChannel = MethodChannel(
    'space_chicken/vibration',
  );

  SharedPreferences? _preferences;
  AudioPlayer? _musicPlayer;
  AudioPlayer? _buttonPlayer;
  AudioPlayer? _transitionPlayer;

  bool _initialized = false;
  bool _audioAvailable = true;
  bool _musicStarted = false;

  bool musicEnabled = true;
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  String language = 'ru';

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await _loadPreferences();

    _initialized = true;
    try {
      _musicPlayer = AudioPlayer();
      _buttonPlayer = AudioPlayer();
      _transitionPlayer = AudioPlayer();

      await _musicPlayer?.setLoopMode(LoopMode.one);
      await _musicPlayer?.setVolume(0.45);
      await _musicPlayer?.setAsset(_gameMusic);
      await _buttonPlayer?.setVolume(0.85);
      await _buttonPlayer?.setAsset(_buttonSound);
      await _transitionPlayer?.setVolume(0.8);
      await _transitionPlayer?.setAsset(_transitionSound);
    } on MissingPluginException {
      _audioAvailable = false;
      return;
    } on PlatformException {
      _audioAvailable = false;
      return;
    }

    await syncMusic();
  }

  Future<void> syncMusic() async {
    await _ensureInitialized();
    if (!_audioAvailable) {
      return;
    }

    if (musicEnabled) {
      await _playMusic();
    } else {
      await _musicPlayer?.stop();
      _musicStarted = false;
    }
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    await _preferences?.setBool(musicKey, value);
    await syncMusic();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    await _preferences?.setBool(soundKey, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    await _loadPreferences();
    vibrationEnabled = value;
    await _preferences?.setBool(vibrationKey, value);
  }

  Future<void> playCrashVibration() async {
    await _loadPreferences();
    if (!vibrationEnabled) {
      return;
    }

    try {
      await _vibrationChannel.invokeMethod<void>('crash');
    } on MissingPluginException {
      await HapticFeedback.vibrate();
    } on PlatformException {
      await HapticFeedback.vibrate();
    }
  }

  Future<void> setLanguage(String value) async {
    language = value;
    await _preferences?.setString(languageKey, value);
  }

  Future<void> playButtonSound() async {
    await _playEffect(_buttonPlayer);
  }

  Future<void> playTransitionSound() async {
    await _playEffect(_transitionPlayer);
  }

  Future<void> pauseMusic() async {
    if (!_audioAvailable) {
      return;
    }

    await _musicPlayer?.pause();
  }

  Future<void> resumeMusic() async {
    if (!_audioAvailable || !musicEnabled) {
      return;
    }

    final player = _musicPlayer;
    if (player == null) {
      return;
    }

    if (player.playing) {
      return;
    }

    try {
      if (_musicStarted) {
        await player.play();
        return;
      }

      await syncMusic();
    } on MissingPluginException {
      _audioAvailable = false;
      _musicStarted = false;
    } on PlatformException {
      _audioAvailable = false;
      _musicStarted = false;
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer?.stop();
    _musicStarted = false;
  }

  void handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(resumeMusic());
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(pauseMusic());
      case AppLifecycleState.detached:
        unawaited(stopMusic());
    }
  }

  Future<void> dispose() async {
    await _musicPlayer?.dispose();
    await _buttonPlayer?.dispose();
    await _transitionPlayer?.dispose();
  }

  Future<void> _playMusic() async {
    if (_musicStarted) {
      return;
    }

    try {
      final player = _musicPlayer;
      if (player == null) {
        return;
      }
      unawaited(player.play().catchError(_disableAudio));
      _musicStarted = true;
    } on MissingPluginException {
      _audioAvailable = false;
      _musicStarted = false;
    } on PlatformException {
      _audioAvailable = false;
      _musicStarted = false;
    }
  }

  Future<void> _playEffect(AudioPlayer? player) async {
    await _ensureInitialized();
    if (!_audioAvailable || !soundEnabled || player == null) {
      return;
    }

    try {
      await player.seek(Duration.zero);
      unawaited(player.play().catchError(_disableAudio));
    } on MissingPluginException {
      _audioAvailable = false;
    } on PlatformException {
      _audioAvailable = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  Future<void> _loadPreferences() async {
    _preferences ??= await SharedPreferences.getInstance();
    musicEnabled = _preferences?.getBool(musicKey) ?? true;
    soundEnabled = _preferences?.getBool(soundKey) ?? true;
    vibrationEnabled = _preferences?.getBool(vibrationKey) ?? true;
    language = _preferences?.getString(languageKey) ?? 'ru';
  }

  void _disableAudio(Object error) {
    _audioAvailable = false;
    _musicStarted = false;
  }
}
