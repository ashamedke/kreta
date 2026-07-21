import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/project.dart';
import '../services/timing_resolver.dart';
import '../services/preview_sound_service.dart';

class PlaybackEngine extends ChangeNotifier {
  Project _project;
  late final Ticker _ticker;
  
  double _currentRealtimeMs = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration? _lastTick;
  
  List<ResolvedTiming> _resolvedTimings = [];
  int _currentPlyIndex = 0;

  PlaybackEngine({required Project project}) : _project = project {
    _ticker = Ticker(_onTick);
    _updateResolvedTimings();
    _syncPlyIndexWithTime(-1);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Project get project => _project;
  double get currentRealtimeMs => _currentRealtimeMs;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  int get currentPlyIndex => _currentPlyIndex;
  
  double get totalMs => _resolvedTimings.fold(0.0, (s, t) => s + t.holdDurationMs + t.transitionDurationMs);
  List<ResolvedTiming> get resolvedTimings => _resolvedTimings;

  void updateProject(Project project) {
    _project = project;
    _updateResolvedTimings();
    notifyListeners();
  }

  void _updateResolvedTimings() {
    _resolvedTimings = TimingResolver().resolveAllTimings(_project.game.plies, _project.timeline.timingRules);
  }

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    
    if (_currentRealtimeMs >= totalMs) {
      _currentRealtimeMs = 0;
      _currentPlyIndex = 0;
    }
    
    _lastTick = null;
    _ticker.start();
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _ticker.stop();
    _lastTick = null;
    PreviewSoundService().stopTyping();
    notifyListeners();
  }

  void togglePlay() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seek(double ms) {
    _currentRealtimeMs = ms.clamp(0.0, totalMs);
    _syncPlyIndexWithTime(-1); // -1 means don't trigger sounds for seek
    notifyListeners();
  }

  void setSpeed(double speed) {
    _playbackSpeed = speed;
    notifyListeners();
  }
  
  void goToPly(int index) {
    _currentPlyIndex = index;
    double accum = 0;
    for (int i = 0; i < index - 1; i++) {
       final timing = i < _resolvedTimings.length ? _resolvedTimings[i] : ResolvedTiming(holdDurationMs: 2000, transitionDurationMs: 500, appliedRules: []);
       accum += timing.holdDurationMs + timing.transitionDurationMs;
    }
    seek(accum);
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    
    if (_lastTick != null) {
      final delta = (elapsed - _lastTick!).inMilliseconds.toDouble() * _playbackSpeed;
      final previousTime = _currentRealtimeMs;
      _currentRealtimeMs += delta;
      
      _syncPlyIndexWithTime(previousTime);
      notifyListeners();
    }
    _lastTick = elapsed;
  }

  void _syncPlyIndexWithTime(double previousTime) {
    double accum = 0;
    
    for (int i = 0; i < _project.game.plies.length; i++) {
      final timing = i < _resolvedTimings.length ? _resolvedTimings[i] : ResolvedTiming(holdDurationMs: 2000, transitionDurationMs: 500, appliedRules: []);
      final total = timing.holdDurationMs + timing.transitionDurationMs;
      
      final transitionEnd = accum + timing.transitionDurationMs;
      
      // If we crossed the transition threshold normally during playback (previousTime >= 0)
      if (previousTime >= 0 && previousTime < transitionEnd && _currentRealtimeMs >= transitionEnd && _isPlaying) {
         final ply = _project.game.plies[i];
         PreviewSoundService().playMoveSound(
            isCapture: ply.capturedPiece != null,
            isPromotion: ply.isPromotion,
            isCheck: ply.isCheck,
         );
      }
      
      if (_currentRealtimeMs >= accum && _currentRealtimeMs < accum + total) {
        if (_currentPlyIndex != i + 1) {
          _currentPlyIndex = i + 1;
        }
        
        final ply = _project.game.plies[i];
        final textLen = (ply.annotation ?? '').length;
        if (textLen > 0 && _isPlaying && previousTime >= 0) {
            final holdTime = _currentRealtimeMs - (accum + timing.transitionDurationMs);
            final typeTimeMs = (textLen / 20.0) * 1000.0;
            if (holdTime > 0 && holdTime < typeTimeMs) {
                PreviewSoundService().startTyping();
            } else {
                PreviewSoundService().stopTyping();
            }
        } else {
            PreviewSoundService().stopTyping();
        }
        
        return;
      }
      accum += total;
    }
    
    if (_currentRealtimeMs >= accum && previousTime >= 0) {
      pause();
    }
  }
}
