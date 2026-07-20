
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import 'package:file_picker/file_picker.dart';
import '../models/game.dart' show FloatingText, BoardArrow;
import '../models/timeline.dart';
import '../services/project_service.dart';
import '../services/timing_resolver.dart';
import '../services/preview_sound_service.dart';
import '../utils/virtual_clock.dart';
import '../widgets/render_engine.dart';
import '../widgets/timeline_editor.dart';
import '../widgets/timing_panel.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    if (_project == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Column(
        children: [
          // Toolbar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF161B22),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 16),
                Text(_project!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: 'Save',
                  onPressed: () => context.read<ProjectService>().saveProject(_project!),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/export', arguments: _project),
                  icon: const Icon(Icons.movie_creation),
                  label: const Text('Export'),
                ),
              ],
            ),
          ),
          
          // Main Body
          Expanded(
            child: Row(
              children: [
                // Left Column: WYSIWYG Preview
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: RenderEngineWidget(
                            project: _project!,
                            preset: RenderPreset(name: 'Preview', width: 1920, height: 1080, fps: 60, videoBitrate: 5000),
                            clock: _clock,
                            resolvedTimings: _resolvedTimings,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Right Column: Settings and Annotations
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Color(0xFF30363D))),
                      color: Color(0xFF161B22),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                    children: [
                      // Annotation Editor
                      const Text('Annotation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _annotationController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Enter text to display during this move...',
                          filled: true,
                          fillColor: Color(0xFF0D1117),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _saveAnnotation,
                      ),
                      const SizedBox(height: 16),
                      
                      // Flag
                      CheckboxListTile(
                        title: const Text('Important Moment'),
                        value: _currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length
                            ? _project!.game.plies[_currentPlyIndex - 1].isFlagged
                            : false,
                        onChanged: (val) {
                          if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
                            setState(() {
                              _project!.game.plies[_currentPlyIndex - 1] = _project!.game.plies[_currentPlyIndex - 1].copyWith(isFlagged: val ?? false);
                            });
                            context.read<ProjectService>().saveProject(_project!);
                          }
                        },
                        activeColor: const Color(0xFF58A6FF),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),
                      
                      // Floating Texts Section
                      const Text('Floating Texts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length)
                        ..._project!.game.plies[_currentPlyIndex - 1].floatingTexts.asMap().entries.map((e) {
                           int idx = e.key;
                           var t = e.value;
                           return ListTile(
                             title: Text(t.text),
                             subtitle: Text('x: ${t.x.toStringAsFixed(2)}, y: ${t.y.toStringAsFixed(2)}'),
                             trailing: IconButton(
                               icon: const Icon(Icons.delete, color: Colors.red),
                               onPressed: () {
                                  setState(() {
                                    var ply = _project!.game.plies[_currentPlyIndex - 1];
                                    var newTexts = List<FloatingText>.from(ply.floatingTexts)..removeAt(idx);
                                    _project!.game.plies[_currentPlyIndex - 1] = ply.copyWith(floatingTexts: newTexts);
                                    context.read<ProjectService>().saveProject(_project!);
                                  });
                               },
                             ),
                           );
                        }).toList(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Text Label'),
                        onPressed: () {
                          if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
                             setState(() {
                               var ply = _project!.game.plies[_currentPlyIndex - 1];
                               var newTexts = List<FloatingText>.from(ply.floatingTexts)..add(const FloatingText(text: "New Text", x: 0.5, y: 0.1));
                               _project!.game.plies[_currentPlyIndex - 1] = ply.copyWith(floatingTexts: newTexts);
                               context.read<ProjectService>().saveProject(_project!);
                             });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Arrows Section
                      const Text('Arrows', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length)
                        ..._project!.game.plies[_currentPlyIndex - 1].arrows.asMap().entries.map((e) {
                           int idx = e.key;
                           var a = e.value;
                           return ListTile(
                             title: Text('${a.fromSquare} -> ${a.toSquare}'),
                             trailing: IconButton(
                               icon: const Icon(Icons.delete, color: Colors.red),
                               onPressed: () {
                                  setState(() {
                                    var ply = _project!.game.plies[_currentPlyIndex - 1];
                                    var newArrows = List<BoardArrow>.from(ply.arrows)..removeAt(idx);
                                    _project!.game.plies[_currentPlyIndex - 1] = ply.copyWith(arrows: newArrows);
                                    context.read<ProjectService>().saveProject(_project!);
                                  });
                               },
                             ),
                           );
                        }).toList(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Arrow'),
                        onPressed: () {
                          if (_currentPlyIndex > 0 && _currentPlyIndex <= _project!.game.plies.length) {
                             setState(() {
                               var ply = _project!.game.plies[_currentPlyIndex - 1];
                               var newArrows = List<BoardArrow>.from(ply.arrows)..add(BoardArrow(fromSquare: "e2", toSquare: "e4"));
                               _project!.game.plies[_currentPlyIndex - 1] = ply.copyWith(arrows: newArrows);
                               context.read<ProjectService>().saveProject(_project!);
                             });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Media Overlays Section
                      const Text('Media Overlays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ..._project!.timeline.layers.where((l) => l.type == LayerType.overlay).map((layer) {
                           return ListTile(
                             title: Text(layer.assetPath.split('\\').last),
                             subtitle: Text('Start: ${layer.startTimeMs}ms'),
                             trailing: IconButton(
                               icon: const Icon(Icons.delete, color: Colors.red),
                               onPressed: () {
                                  setState(() {
                                    var newLayers = List<Layer>.from(_project!.timeline.layers)..removeWhere((l) => l.id == layer.id);
                                    _project = _project!.copyWith(timeline: _project!.timeline.copyWith(layers: newLayers));
                                    context.read<ProjectService>().saveProject(_project!);
                                  });
                               },
                             ),
                           );
                      }).toList(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Add Image/Video'),
                        onPressed: () async {
                           FilePickerResult? result = await FilePicker.platform.pickFiles(
                             type: FileType.media,
                           );
                           if (result != null && result.files.single.path != null) {
                              setState(() {
                                var newLayer = Layer(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  type: LayerType.overlay,
                                  assetPath: result.files.single.path!,
                                  startTimeMs: _realtimeMs.toInt(),
                                  endTimeMs: _realtimeMs.toInt() + 5000, // Default 5 seconds
                                  x: 0.1, y: 0.1, width: 0.3, height: 0.3,
                                );
                                var newLayers = List<Layer>.from(_project!.timeline.layers)..add(newLayer);
                                _project = _project!.copyWith(timeline: _project!.timeline.copyWith(layers: newLayers));
                                context.read<ProjectService>().saveProject(_project!);
                              });
                           }
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Timing Panel
                      TimingPanel(
                        timingRules: _project!.timeline.timingRules,
                        totalDurationMs: 0,
                        onChanged: (rules) {
                          setState(() {
                            _project = _project!.copyWith(timeline: _project!.timeline.copyWith(timingRules: rules));
                            _updateResolvedTimings();
                          });
                          context.read<ProjectService>().saveProject(_project!);
                        }
                      ),
                    ],
                  ),
                ),
                ),
              ],
            ),
          ),
          
          // Bottom Controls & Timeline
          Container(
            height: 200,
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(top: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Column(
              children: [
                // Playback Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () {
                          if (_currentPlyIndex > 0) _goToPly(_currentPlyIndex - 1);
                        },
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        color: const Color(0xFF58A6FF),
                        iconSize: 32,
                        onPressed: _togglePlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: () {
                          if (_currentPlyIndex < _project!.game.plies.length) {
                            _goToPly(_currentPlyIndex + 1);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Text('Move: ${_currentPlyIndex ~/ 2 + 1}'),
                      const Spacer(),
                      DropdownButton<double>(
                        value: _playbackSpeed,
                        dropdownColor: const Color(0xFF161B22),
                        items: [0.5, 1.0, 1.5, 2.0].map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s}x Speed'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _playbackSpeed = val);
                        },
                      ),
                    ],
                  ),
                ),
                // Timeline Editor
                Expanded(
                  child: TimelineEditor(
                    project: _project!,
                    resolvedTimings: _resolvedTimings,
                    currentPlyIndex: _currentPlyIndex,
                    onPlySelected: _goToPly,
                    onTimingChanged: (rules) {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
