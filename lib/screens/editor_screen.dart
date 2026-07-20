
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import 'package:file_picker/file_picker.dart';
import '../models/game.dart' show FloatingText, BoardArrow;
import '../models/render_job.dart';
import '../models/timeline.dart';
import '../services/project_service.dart';
import '../services/timing_resolver.dart';
import '../services/preview_sound_service.dart';
import '../utils/virtual_clock.dart';
import '../widgets/render_engine.dart';
import '../widgets/timeline_editor.dart';
import '../widgets/timing_panel.dart';

// â”€â”€ colour tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _bg        = Color(0xFF0D1117);
const _surface   = Color(0xFF161B22);
const _surface2  = Color(0xFF21262D);
const _border    = Color(0xFF30363D);
const _accent    = Color(0xFF58A6FF);
const _accentDim = Color(0xFF1F3A5F);
const _textPri   = Color(0xFFE6EDF3);
const _textSec   = Color(0xFF8B949E);
const _red       = Color(0xFFF85149);

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  Project? _project;
  int _currentPlyIndex = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  late Ticker _ticker;
  late VirtualClock _clock;
  double _realtimeMs = 0;
  Duration? _lastTick;

  List<ResolvedTiming> _resolvedTimings = [];
  final _annotationController = TextEditingController();

  // 0=Notes 1=Overlays 2=Timing
  int _rightTab = 0;
  final _moveScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _clock = VirtualClock(fps: 60);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null) {
      final proj = ModalRoute.of(context)!.settings.arguments as Project;
      _project = proj;
      _updateResolvedTimings();
      _loadAnnotation();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _annotationController.dispose();
    _moveScroll.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying || _project == null) return;
    
    if (_lastTick != null) {
      final delta = (elapsed - _lastTick!).inMilliseconds.toDouble() * _playbackSpeed;
      setState(() {
        final previousTime = _realtimeMs;
        _realtimeMs += delta;
        _clock.seekToTime(_realtimeMs);
        _syncPlyIndexWithTime(previousTime);
      });
    }
    _lastTick = elapsed;
  }

  void _syncPlyIndexWithTime(double previousTime) {
    if (_project == null) return;
    double accum = 0;
    
    // Find which ply we are currently in
    for (int i = 0; i < _project!.game.plies.length; i++) {
      final timing = i < _resolvedTimings.length ? _resolvedTimings[i] : ResolvedTiming(holdDurationMs: 2000, transitionDurationMs: 500, appliedRules: []);
      final total = timing.holdDurationMs + timing.transitionDurationMs;
      
      final transitionEnd = accum + timing.transitionDurationMs;
      if (previousTime < transitionEnd && _realtimeMs >= transitionEnd && _isPlaying) {
         final ply = _project!.game.plies[i];
         PreviewSoundService().playMoveSound(
            isCapture: ply.capturedPiece != null,
            isPromotion: ply.isPromotion,
            isCheck: ply.isCheck,
         );
      }
      
      if (_realtimeMs >= accum && _realtimeMs < accum + total) {
        if (_currentPlyIndex != i + 1) {
          _currentPlyIndex = i + 1;
          _loadAnnotation();
        }
        final ply = _project!.game.plies[i];
        final textLen = (ply.annotation ?? '').length;
        if (textLen > 0 && _isPlaying) {
            final holdTime = _realtimeMs - (accum + timing.transitionDurationMs);
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
    
    // If we exceed total duration, stop playback
    if (_realtimeMs >= accum) {
      _isPlaying = false;
      _ticker.stop();
      _lastTick = null;
    }
  }

  void _updateResolvedTimings() {
    if (_project != null) {
      _resolvedTimings = TimingResolver().resolveAllTimings(_project!.game.plies, _project!.timeline.timingRules);
    }
  }

  void _loadAnnotation() {
    if (_project != null && _currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
      _annotationController.text = _project!.game.plies[_currentPlyIndex - 1].annotation ?? '';
    } else {
      _annotationController.text = '';
    }
  }

  void _saveAnnotation(String text) {
    if (_project != null && _currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
      _project!.game.plies[_currentPlyIndex - 1] = _project!.game.plies[_currentPlyIndex - 1].copyWith(annotation: text);
      context.read<ProjectService>().saveProject(_project!);
    }
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        // if we are at the end, restart
        double totalTime = _resolvedTimings.fold(0.0, (sum, t) => sum + t.holdDurationMs + t.transitionDurationMs);
        if (_realtimeMs >= totalTime) {
           _realtimeMs = 0;
           _clock.seekToTime(0);
           _currentPlyIndex = 0;
        }
        
        _lastTick = null;
        _ticker.start();
      } else {
        _ticker.stop();
        _lastTick = null;
        PreviewSoundService().stopTyping();
      }
    });
  }

  void _goToPly(int index) {
    setState(() {
      _currentPlyIndex = index;
      _loadAnnotation();
      
      // Calculate time for this ply
      double accum = 0;
      for (int i = 0; i < index - 1; i++) {
         final timing = i < _resolvedTimings.length ? _resolvedTimings[i] : ResolvedTiming(holdDurationMs: 2000, transitionDurationMs: 500, appliedRules: []);
         accum += timing.holdDurationMs + timing.transitionDurationMs;
      }
      _realtimeMs = accum;
      _clock.seekToTime(_realtimeMs);
    });
  }

  // â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  double get _totalMs => _resolvedTimings.fold(
      0.0, (s, t) => s + t.holdDurationMs + t.transitionDurationMs);

  String _fmt(double ms) {
    final secs = (ms / 1000).floor();
    final frac = ((ms % 1000) / 100).floor();
    final m = secs ~/ 60, s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$frac';
  }

  Ply? get _curPly =>
      (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length)
          ? _project!.game.plies[_currentPlyIndex - 1]
          : null;

  // â”€â”€ build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    if (_project == null) {
      return const Scaffold(
          backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _accent)));
    }
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _toolbar(),
          Expanded(
            child: Row(children: [
              _moveList(),
              Expanded(flex: 5, child: _preview()),
              _rightPanel(),
            ]),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  // â”€â”€ toolbar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _toolbar() => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
            color: _surface, border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          Tooltip(
            message: 'Back',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => Navigator.pop(context),
              child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _textSec)),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 28, color: _border),
          const SizedBox(width: 12),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_accent, Color(0xFF7C3AED)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.videocam, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(_project!.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPri),
                overflow: TextOverflow.ellipsis),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _surface2, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
            child: Text(
              '${_project!.game.plies.length ~/ 2} moves  Â·  ${_fmt(_totalMs)}',
              style: const TextStyle(fontSize: 12, color: _textSec),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Save',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => context.read<ProjectService>().saveProject(_project!),
              child: const Padding(padding: EdgeInsets.all(8),
                  child: Icon(Icons.save_outlined, size: 18, color: _textSec)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/export', arguments: _project),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_accent, Color(0xFF7C3AED)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.movie_creation_outlined, size: 15, color: Colors.white),
                SizedBox(width: 6),
                Text('Export Video',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      );

  // â”€â”€ move list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _moveList() {
    final plies = _project!.game.plies;
    final moveCount = (plies.length / 2).ceil();
    return Container(
      width: 176,
      decoration: const BoxDecoration(
          color: _surface, border: Border(right: BorderSide(color: _border))),
      child: Column(children: [
        Container(
          height: 36,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
          child: const Text('MOVES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textSec, letterSpacing: 1.0)),
        ),
        Expanded(
          child: ListView.builder(
            controller: _moveScroll,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: moveCount,
            itemBuilder: (ctx, i) {
              final wi = i * 2, bi = i * 2 + 1;
              final wp = plies[wi];
              final bp = bi < plies.length ? plies[bi] : null;
              final wa = _currentPlyIndex == wi + 1;
              final ba = bp != null && _currentPlyIndex == bi + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Row(children: [
                  SizedBox(
                    width: 26,
                    child: Text('${i + 1}.',
                        style: const TextStyle(fontSize: 10, color: _textSec, fontFamily: 'monospace')),
                  ),
                  Expanded(child: _MoveChip(san: wp.san, active: wa, flagged: wp.isFlagged,
                      hasNote: (wp.annotation ?? '').isNotEmpty, onTap: () => _goToPly(wi + 1))),
                  const SizedBox(width: 2),
                  Expanded(child: bp != null
                      ? _MoveChip(san: bp.san, active: ba, flagged: bp.isFlagged,
                          hasNote: (bp.annotation ?? '').isNotEmpty, onTap: () => _goToPly(bi + 1))
                      : const SizedBox()),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  // â”€â”€ preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _preview() => Container(
        color: _bg,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: 2)],
                  border: Border.all(color: _border),
                ),
                clipBehavior: Clip.antiAlias,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RenderEngineWidget(
                    project: _project!,
                    preset: const RenderPreset(name: 'Preview', width: 1920, height: 1080, fps: 60, videoBitrate: 5000),
                    clock: _clock,
                    resolvedTimings: _resolvedTimings,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _scrubber(),
          ]),
        ),
      );

  Widget _scrubber() {
    final total = _totalMs;
    final progress = total > 0 ? (_realtimeMs / total).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: _accent, inactiveTrackColor: _border,
          thumbColor: _accent, overlayColor: _accent.withValues(alpha: 0.18),
        ),
        child: Slider(
          value: progress,
          onChanged: (v) => setState(() {
            _realtimeMs = v * total;
            _clock.seekToTime(_realtimeMs);
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmt(_realtimeMs), style: const TextStyle(fontSize: 11, color: _textSec, fontFamily: 'monospace')),
          Text(_fmt(total), style: const TextStyle(fontSize: 11, color: _textSec, fontFamily: 'monospace')),
        ]),
      ),
    ]);
  }

  // â”€â”€ right panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _rightPanel() => Container(
        width: 254,
        decoration: const BoxDecoration(
            color: _surface, border: Border(left: BorderSide(color: _border))),
        child: Column(children: [
          Container(
            height: 40,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
            child: Row(children: [
              _Tab('Notes', 0, _rightTab, (i) => setState(() => _rightTab = i)),
              _Tab('Overlays', 1, _rightTab, (i) => setState(() => _rightTab = i)),
              _Tab('Timing', 2, _rightTab, (i) => setState(() => _rightTab = i)),
            ]),
          ),
          Expanded(
            child: IndexedStack(index: _rightTab, children: [
              _notesTab(),
              _overlaysTab(),
              _timingTab(),
            ]),
          ),
        ]),
      );

  Widget _notesTab() {
    final ply = _curPly;
    return ListView(padding: const EdgeInsets.all(14), children: [
      if (ply != null) ...[
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: _accentDim, borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _accent.withValues(alpha: 0.5))),
            child: Text('Move ${(_currentPlyIndex / 2).ceil()} Â· ${ply.san}',
                style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          ),
          const Spacer(),
          if (ply.isCheck)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _red.withValues(alpha: 0.5))),
              child: const Text('Check', style: TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 14),
      ],
      const _Label('ANNOTATION'),
      const SizedBox(height: 6),
      TextField(
        controller: _annotationController,
        maxLines: 5,
        style: const TextStyle(fontSize: 13, color: _textPri),
        decoration: InputDecoration(
          hintText: 'Add commentary for this moveâ€¦',
          hintStyle: const TextStyle(color: _textSec, fontSize: 13),
          filled: true, fillColor: _surface2,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent)),
        ),
        onChanged: _saveAnnotation,
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: () {
          if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
            setState(() {
              _project!.game.plies[_currentPlyIndex - 1] = _project!.game.plies[_currentPlyIndex - 1]
                  .copyWith(isFlagged: !(ply?.isFlagged ?? false));
            });
            context.read<ProjectService>().saveProject(_project!);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(Icons.flag_rounded, size: 16,
                color: (ply?.isFlagged ?? false) ? const Color(0xFFF7CC5A) : _textSec),
            const SizedBox(width: 8),
            const Expanded(child: Text('Flag as Important', style: TextStyle(fontSize: 13, color: _textPri))),
            Switch(
              value: ply?.isFlagged ?? false,
              onChanged: (val) {
                if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
                  setState(() {
                    _project!.game.plies[_currentPlyIndex - 1] =
                        _project!.game.plies[_currentPlyIndex - 1].copyWith(isFlagged: val);
                  });
                  context.read<ProjectService>().saveProject(_project!);
                }
              },
              activeColor: _accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      const _Label('ARROWS'),
      const SizedBox(height: 6),
      if (ply != null)
        ...ply.arrows.asMap().entries.map((e) => _Chip(
              label: '${e.value.fromSquare} â†’ ${e.value.toSquare}',
              onDelete: () => setState(() {
                final p = _project!.game.plies[_currentPlyIndex - 1];
                final na = List<BoardArrow>.from(p.arrows)..removeAt(e.key);
                _project!.game.plies[_currentPlyIndex - 1] = p.copyWith(arrows: na);
                context.read<ProjectService>().saveProject(_project!);
              }),
            )),
      const SizedBox(height: 6),
      _Btn(
        label: 'Add Arrow', icon: Icons.arrow_forward,
        onPressed: () {
          if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
            setState(() {
              final p = _project!.game.plies[_currentPlyIndex - 1];
              final na = List<BoardArrow>.from(p.arrows)..add(BoardArrow(fromSquare: 'e2', toSquare: 'e4'));
              _project!.game.plies[_currentPlyIndex - 1] = p.copyWith(arrows: na);
              context.read<ProjectService>().saveProject(_project!);
            });
          }
        },
      ),
      const SizedBox(height: 16),
      const _Label('FLOATING LABELS'),
      const SizedBox(height: 6),
      if (ply != null)
        ...ply.floatingTexts.asMap().entries.map((e) => _Chip(
              label: e.value.text,
              onDelete: () => setState(() {
                final p = _project!.game.plies[_currentPlyIndex - 1];
                final nt = List<FloatingText>.from(p.floatingTexts)..removeAt(e.key);
                _project!.game.plies[_currentPlyIndex - 1] = p.copyWith(floatingTexts: nt);
                context.read<ProjectService>().saveProject(_project!);
              }),
            )),
      const SizedBox(height: 6),
      _Btn(
        label: 'Add Label', icon: Icons.text_fields,
        onPressed: () {
          if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
            setState(() {
              final p = _project!.game.plies[_currentPlyIndex - 1];
              final nt = List<FloatingText>.from(p.floatingTexts)
                ..add(const FloatingText(text: 'New Text', x: 0.5, y: 0.1));
              _project!.game.plies[_currentPlyIndex - 1] = p.copyWith(floatingTexts: nt);
              context.read<ProjectService>().saveProject(_project!);
            });
          }
        },
      ),
    ]);
  }

  Widget _overlaysTab() {
    final ols = _project!.timeline.layers.where((l) => l.type == LayerType.overlay).toList();
    return ListView(padding: const EdgeInsets.all(14), children: [
      const _Label('MEDIA OVERLAYS'),
      const SizedBox(height: 8),
      if (ols.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No overlays yet', style: TextStyle(fontSize: 12, color: _textSec), textAlign: TextAlign.center),
        ),
      ...ols.map((layer) {
        final name = layer.assetPath.split(RegExp(r'[\\/]')).last;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
            child: Row(children: [
              const Icon(Icons.perm_media_outlined, size: 16, color: _textSec),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 12, color: _textPri), overflow: TextOverflow.ellipsis),
                Text('@ ${layer.startTimeMs}ms', style: const TextStyle(fontSize: 10, color: _textSec)),
              ])),
              GestureDetector(
                onTap: () => setState(() {
                  final nl = List<Layer>.from(_project!.timeline.layers)..removeWhere((l) => l.id == layer.id);
                  _project = _project!.copyWith(timeline: _project!.timeline.copyWith(layers: nl));
                  context.read<ProjectService>().saveProject(_project!);
                }),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: _red),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
      _Btn(
        label: 'Add Image / Video', icon: Icons.add_photo_alternate_outlined,
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(type: FileType.media);
          if (result != null && result.files.single.path != null) {
            setState(() {
              final nl = List<Layer>.from(_project!.timeline.layers)
                ..add(Layer(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  type: LayerType.overlay,
                  assetPath: result.files.single.path!,
                  startTimeMs: _realtimeMs.toInt(),
                  endTimeMs: _realtimeMs.toInt() + 5000,
                  x: 0.1, y: 0.1, width: 0.3, height: 0.3,
                ));
              _project = _project!.copyWith(timeline: _project!.timeline.copyWith(layers: nl));
              context.read<ProjectService>().saveProject(_project!);
            });
          }
        },
      ),
    ]);
  }

  Widget _timingTab() => ListView(padding: const EdgeInsets.all(14), children: [
    const _Label('TIMING RULES'),
    const SizedBox(height: 10),
    TimingPanel(
      timingRules: _project!.timeline.timingRules,
      totalDurationMs: 0,
      onChanged: (rules) {
        setState(() {
          _project = _project!.copyWith(timeline: _project!.timeline.copyWith(timingRules: rules));
          _updateResolvedTimings();
        });
        context.read<ProjectService>().saveProject(_project!);
      },
    ),
  ]);

  // â”€â”€ bottom bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _bottomBar() {
    final plies = _project!.game.plies;
    return Container(
      decoration: const BoxDecoration(color: _surface, border: Border(top: BorderSide(color: _border))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              color: _currentPlyIndex > 0 ? _textPri : _border,
              iconSize: 22, splashRadius: 18,
              onPressed: _currentPlyIndex > 0 ? () => _goToPly(_currentPlyIndex - 1) : null,
            ),
            GestureDetector(
              onTap: _togglePlay,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: _isPlaying ? _accent : _accentDim,
                    borderRadius: BorderRadius.circular(20)),
                child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              color: _currentPlyIndex < plies.length ? _textPri : _border,
              iconSize: 22, splashRadius: 18,
              onPressed: _currentPlyIndex < plies.length ? () => _goToPly(_currentPlyIndex + 1) : null,
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: _border),
            const SizedBox(width: 12),
            Text(
              _currentPlyIndex > 0
                  ? 'Move ${(_currentPlyIndex / 2).ceil()}  Â·  ${plies[_currentPlyIndex - 1].san}'
                  : 'Start position',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPri, fontFamily: 'monospace'),
            ),
            const Spacer(),
            const Text('Speed', style: TextStyle(fontSize: 12, color: _textSec)),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: _playbackSpeed,
                dropdownColor: _surface2,
                style: const TextStyle(color: _textPri, fontSize: 13),
                borderRadius: BorderRadius.circular(8),
                items: [0.25, 0.5, 1.0, 1.5, 2.0]
                    .map((s) => DropdownMenuItem(value: s, child: Text('${s}Ã—')))
                    .toList(),
                onChanged: (val) { if (val != null) setState(() => _playbackSpeed = val); },
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 96,
          child: TimelineEditor(
            project: _project!,
            resolvedTimings: _resolvedTimings,
            currentPlyIndex: _currentPlyIndex,
            onPlySelected: _goToPly,
            onTimingChanged: (_) {},
          ),
        ),
      ]),
    );
  }
}

// â”€â”€â”€ shared micro-widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MoveChip extends StatelessWidget {
  final String san;
  final bool active, flagged, hasNote;
  final VoidCallback onTap;
  const _MoveChip({required this.san, required this.active, required this.flagged, required this.hasNote, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: active ? _accentDim : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: active ? Border.all(color: _accent.withValues(alpha: 0.55)) : null,
          ),
          child: Row(children: [
            if (flagged) const Padding(padding: EdgeInsets.only(right: 2), child: Icon(Icons.flag_rounded, size: 8, color: Color(0xFFF7CC5A))),
            Flexible(child: Text(san,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                    color: active ? _accent : _textPri,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal),
                overflow: TextOverflow.ellipsis)),
            if (hasNote) const Padding(padding: EdgeInsets.only(left: 2), child: Icon(Icons.chat_bubble_outline_rounded, size: 7, color: _textSec)),
          ]),
        ),
      );
}

class _Tab extends StatelessWidget {
  final String label;
  final int index, current;
  final void Function(int) onTap;
  const _Tab(this.label, this.index, this.current, this.onTap);
  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? _accent : Colors.transparent, width: 2))),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? _accent : _textSec)),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textSec, letterSpacing: 0.8));
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;
  const _Chip({required this.label, required this.onDelete});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: _textPri, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
            GestureDetector(onTap: onDelete, child: const Icon(Icons.close_rounded, size: 14, color: _red)),
          ]),
        ),
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _Btn({required this.label, required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 14),
          label: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
}

