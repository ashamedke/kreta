import 'dart:math' as math;

class VirtualClock {
  final int fps;
  int _currentFrame = 0;
  
  VirtualClock({this.fps = 30});
  
  int get currentFrame => _currentFrame;
  double get currentTimeMs => (_currentFrame / fps) * 1000.0;
  double get currentTimeSec => _currentFrame / fps;
  
  void tick() => _currentFrame++;
  void seekToFrame(int frame) => _currentFrame = frame;
  void seekToTime(double timeMs) => _currentFrame = (timeMs / 1000.0 * fps).round();
  void reset() => _currentFrame = 0;
  
  int frameAtTime(double timeMs) => (timeMs / 1000.0 * fps).round();
  int framesForDuration(int durationMs) => (durationMs / 1000.0 * fps).ceil();
  
  double interpolate(double startMs, double endMs) {
    if (currentTimeMs <= startMs) return 0.0;
    if (currentTimeMs >= endMs) return 1.0;
    return (currentTimeMs - startMs) / (endMs - startMs);
  }
  
  double interpolateEased(double startMs, double endMs) {
    final t = interpolate(startMs, endMs);
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
}
