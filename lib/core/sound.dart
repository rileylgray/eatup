import 'dart:math';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Sfx { chomp, gulp, big, pop, coin, powerup, levelup, click, eaten, win, tick, go, star, spin, whoosh, combo }

/// Sound effects, the music loop and haptics, all behind the player's
/// settings. Nothing touches the audio plugin until [init], so tests and
/// unsupported platforms stay silent instead of throwing.
class Sound {
  Sound._();
  static final Sound instance = Sound._();

  bool sfxOn = true;
  bool hapticsOn = true;
  bool _musicOn = true;
  bool _ready = false;
  bool _suspended = false;
  bool _inRound = false;

  final Map<String, AudioPool> _pools = {};
  final Random _rng = Random();
  DateTime _lastChomp = DateTime(2000);

  /// File -> max simultaneous players.
  static const _files = {
    'chomp_0': 4,
    'chomp_1': 4,
    'chomp_2': 4,
    'gulp': 3,
    'big': 2,
    'pop': 3,
    'coin': 3,
    'powerup': 2,
    'levelup': 1,
    'click': 2,
    'eaten': 1,
    'win': 1,
    'tick': 2,
    'go': 1,
    'star': 2,
    'spin': 3,
    'whoosh': 2,
    'combo': 2,
  };

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await FlameAudio.bgm.initialize();
      // One at a time, so a file that won't load only silences itself.
      for (final e in _files.entries) {
        try {
          _pools[e.key] = await FlameAudio.createPool('${e.key}.wav', minPlayers: 1, maxPlayers: e.value);
        } catch (err) {
          debugPrint('Sound ${e.key} unavailable: $err');
        }
      }
      _ready = true;
      _syncMusic(restart: true);
    } catch (e) {
      debugPrint('Audio unavailable: $e');
    }
  }

  void play(Sfx s, {double volume = 1}) {
    if (!sfxOn || !_ready || _suspended) return;
    var key = s.name;
    if (s == Sfx.chomp) {
      // A crowd eaten at once shouldn't machine-gun.
      final now = DateTime.now();
      if (now.difference(_lastChomp).inMilliseconds < 45) return;
      _lastChomp = now;
      key = 'chomp_${_rng.nextInt(3)}';
    }
    _pools[key]?.start(volume: volume).catchError((Object _) => () async {});
  }

  void haptic(Sfx s) {
    if (!hapticsOn) return;
    switch (s) {
      case Sfx.big:
      case Sfx.eaten:
        HapticFeedback.heavyImpact();
      case Sfx.gulp:
      case Sfx.powerup:
      case Sfx.levelup:
      case Sfx.win:
        HapticFeedback.mediumImpact();
      case Sfx.chomp:
      case Sfx.go:
        HapticFeedback.lightImpact();
      case Sfx.click:
      case Sfx.coin:
      case Sfx.star:
      case Sfx.spin:
      case Sfx.tick:
        HapticFeedback.selectionClick();
      case Sfx.pop:
      case Sfx.whoosh:
      case Sfx.combo:
        break;
    }
  }

  /// Sound and haptic together, the common case.
  void fx(Sfx s, {double volume = 1}) {
    play(s, volume: volume);
    haptic(s);
  }

  set musicOn(bool v) {
    if (_musicOn == v) return;
    _musicOn = v;
    _syncMusic(restart: v);
  }

  /// Music is a touch louder in the menus than under a round's sound effects.
  set inRound(bool v) {
    if (_inRound == v) return;
    _inRound = v;
    if (_ready && FlameAudio.bgm.isPlaying) {
      FlameAudio.bgm.audioPlayer.setVolume(v ? 0.32 : 0.5).catchError((Object _) {});
    }
  }

  /// Full-screen ads play their own audio; keep ours out of the way.
  void suspend() {
    _suspended = true;
    _syncMusic();
  }

  void unsuspend() {
    _suspended = false;
    _syncMusic();
  }

  void _syncMusic({bool restart = false}) {
    if (!_ready) return;
    final bgm = FlameAudio.bgm;
    final want = _musicOn && !_suspended;
    try {
      if (!want) {
        if (bgm.isPlaying) bgm.pause();
      } else if (restart || bgm.audioPlayer.source == null) {
        bgm.play('music.wav', volume: _inRound ? 0.32 : 0.5);
      } else if (!bgm.isPlaying) {
        bgm.resume();
      }
    } catch (e) {
      debugPrint('Music failed: $e');
    }
  }
}
