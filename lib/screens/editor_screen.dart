import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/project_service.dart';
import '../services/timing_resolver.dart';
import '../widgets/chess_board_2d.dart';
import '../widgets/terminal_text.dart';
import '../widgets/timeline_editor.dart';
import '../widgets/timing_panel.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Project? _project;
  int _currentPlyIndex = 0;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  bool _flipBoard = false;
  Timer? _playbackTimer;
  List<ResolvedTiming> _resolvedTimings = [];
  
  final _annotationController = TextEditingController();

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
    _playbackTimer?.cancel();
    _annotationController.dispose();
    super.dispose();
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
        _playNext();
      } else {
        _playbackTimer?.cancel();
      }
    });
  }

  void _playNext() {
    if (!_isPlaying || _project == null || _currentPlyIndex >= _project!.game.plies.length) {
      setState(() => _isPlaying = false);
      return;
    }

    // Determine duration for current ply
    double duration = 2.0; // default 2s
    if (_currentPlyIndex < _resolvedTimings.length) {
      duration = _resolvedTimings[_currentPlyIndex].holdDurationMs / 1000.0;
    }
    
    _playbackTimer = Timer(Duration(milliseconds: (duration * 1000 / _playbackSpeed).round()), () {
      if (!mounted) return;
      setState(() {
        _currentPlyIndex++;
        _loadAnnotation();
      });
      _playNext();
    });
  }

  void _goToPly(int index) {
    setState(() {
      _currentPlyIndex = index;
      _loadAnnotation();
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
                IconButton(
                  icon: const Icon(Icons.flip_camera_android),
                  tooltip: 'Flip Board',
                  onPressed: () => setState(() => _flipBoard = !_flipBoard),
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
                // Left Column
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Transform.rotate(
                                angle: _flipBoard ? 3.14159 : 0,
                                child: ChessBoard2D(fen: _project!.game.startingFen, size: 400),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 80,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF30363D)),
                          ),
                          child: TerminalText(
                            fullText: _annotationController.text.isEmpty ? "No annotation for this move." : _annotationController.text,
                            revealProgress: 50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Right Column
                Container(
                  width: 350,
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Color(0xFF30363D))),
                    color: Color(0xFF161B22),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Move List Preview (Simplified)
                      const Text('Moves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_project!.game.plies.length, (index) {
                              final isCurrent = index + 1 == _currentPlyIndex;
                              return InkWell(
                                onTap: () => _goToPly(index + 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCurrent ? const Color(0xFF58A6FF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _project!.game.plies[index].moveSan,
                                    style: TextStyle(
                                      color: isCurrent ? const Color(0xFF0D1117) : const Color(0xFFE6EDF3),
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
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
                      const SizedBox(height: 24),
                      
                      // Timing Panel
                      TimingPanel(timingRules: _project!.timeline.timingRules, totalDurationMs: 0, onChanged: (rules) {}),
                    ],
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
