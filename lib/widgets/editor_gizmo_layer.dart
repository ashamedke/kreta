import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/project.dart';
import '../models/render_job.dart';
import '../models/timeline.dart';
import '../models/selection_model.dart';
import '../models/keyframe.dart';
import '../services/playback_engine.dart';
import '../services/project_service.dart';
import '../utils/constants.dart';

class EditorGizmoLayer extends StatefulWidget {
  final Project project;
  final RenderPreset preset;
  final PlaybackEngine engine;

  const EditorGizmoLayer({
    super.key,
    required this.project,
    required this.preset,
    required this.engine,
  });

  @override
  State<EditorGizmoLayer> createState() => _EditorGizmoLayerState();
}

class _EditorGizmoLayerState extends State<EditorGizmoLayer> {
  // Temporary drag states
  bool _isDragging = false;
  double? _tempX;
  double? _tempY;
  double? _tempWidth;
  double? _tempHeight;
  
  // Arrow drawing states
  String? _arrowStartSquare;
  String? _arrowCurrentSquare;

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineTick);
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineTick);
    super.dispose();
  }

  void _onEngineTick() {
    if (!_isDragging) {
      setState(() {});
    }
  }

  TimelineItem? _getSelectedActiveItem(SelectionModel selection, double currentTimeMs) {
    if (selection.selectedItemId == null) return null;
    
    for (final track in widget.project.timeline.tracks) {
      for (final item in track.items) {
        if (item.id == selection.selectedItemId) {
          if (currentTimeMs >= item.startTimeMs && 
              (item.endTimeMs == null || currentTimeMs < item.endTimeMs!)) {
            return item;
          }
        }
      }
    }
    return null;
  }
  
  void _saveChanges(TimelineItem item) {
    final currentTimeMs = widget.engine.currentRealtimeMs;
    
    if (item is OverlayItem) {
      if (_tempX != null) item.x.setKeyframe(currentTimeMs, _tempX!);
      if (_tempY != null) item.y.setKeyframe(currentTimeMs, _tempY!);
      if (_tempWidth != null) item.width.setKeyframe(currentTimeMs, _tempWidth!);
      if (_tempHeight != null) item.height.setKeyframe(currentTimeMs, _tempHeight!);
    } else if (item is FloatingTextItem) {
      if (_tempX != null) item.x.setKeyframe(currentTimeMs, _tempX!);
      if (_tempY != null) item.y.setKeyframe(currentTimeMs, _tempY!);
    }
    
    ProjectService().saveProject(widget.project);
    
    setState(() {
      _isDragging = false;
      _tempX = null;
      _tempY = null;
      _tempWidth = null;
      _tempHeight = null;
    });
  }

  String? _getSquareFromOffset(Offset localPos, double boardSize, double w, double h) {
    // Board is centered
    final double startX = (w - boardSize) / 2;
    final double startY = (h - boardSize) / 2;
    
    if (localPos.dx < startX || localPos.dx > startX + boardSize ||
        localPos.dy < startY || localPos.dy > startY + boardSize) {
      return null;
    }
    
    final squareSize = boardSize / 8;
    final int col = ((localPos.dx - startX) / squareSize).floor();
    final int row = ((localPos.dy - startY) / squareSize).floor(); // 0 is rank 8
    
    if (col < 0 || col > 7 || row < 0 || row > 7) return null;
    
    final file = String.fromCharCode(97 + col);
    final rank = (8 - row).toString();
    return '$file$rank';
  }

  void _onArrowPanStart(DragStartDetails details, double boardSize, double w, double h) {
    setState(() {
      _arrowStartSquare = _getSquareFromOffset(details.localPosition, boardSize, w, h);
      _arrowCurrentSquare = _arrowStartSquare;
    });
  }

  void _onArrowPanUpdate(DragUpdateDetails details, double boardSize, double w, double h) {
    if (_arrowStartSquare == null) return;
    final sq = _getSquareFromOffset(details.localPosition, boardSize, w, h);
    if (sq != null && sq != _arrowCurrentSquare) {
      setState(() {
        _arrowCurrentSquare = sq;
      });
    }
  }

  void _onArrowPanEnd() {
    if (_arrowStartSquare != null && _arrowCurrentSquare != null && _arrowStartSquare != _arrowCurrentSquare) {
      final currentTimeMs = widget.engine.currentRealtimeMs;
      
      final newItem = ArrowItem(
        startTimeMs: currentTimeMs.toInt(),
        endTimeMs: currentTimeMs.toInt() + 2000,
        fromSquare: _arrowStartSquare!,
        toSquare: _arrowCurrentSquare!,
        color: '#D29922',
      );
      
      // Find an annotation track or create one
      Track? targetTrack;
      for (final track in widget.project.timeline.tracks) {
        if (track.type == TrackType.annotation) {
          targetTrack = track;
          break;
        }
      }
      
      if (targetTrack == null) {
        targetTrack = Track(id: 'track_${DateTime.now().millisecondsSinceEpoch}', name: 'Arrows', type: TrackType.annotation);
        widget.project.timeline.tracks.add(targetTrack);
      }
      
      targetTrack.items.add(newItem);
      ProjectService().saveProject(widget.project);
    }
    
    setState(() {
      _arrowStartSquare = null;
      _arrowCurrentSquare = null;
    });
    
    // Switch back to select mode after drawing one arrow
    context.read<SelectionModel>().setToolMode(ToolMode.select);
  }

  @override
  Widget build(BuildContext context) {
    final selection = context.watch<SelectionModel>();
    final double w = widget.preset.width.toDouble();
    final double h = widget.preset.height.toDouble();
    final double boardSize = math.min(w, h);
    
    final currentTimeMs = widget.engine.currentRealtimeMs;

    if (selection.toolMode == ToolMode.drawArrow) {
      return GestureDetector(
        onPanStart: (d) => _onArrowPanStart(d, boardSize, w, h),
        onPanUpdate: (d) => _onArrowPanUpdate(d, boardSize, w, h),
        onPanEnd: (_) => _onArrowPanEnd(),
        child: Container(
          color: Colors.transparent, // Capture all gestures
          width: w,
          height: h,
          child: _arrowStartSquare != null && _arrowCurrentSquare != null
              ? _buildTemporaryArrow(boardSize, w, h)
              : null,
        ),
      );
    }

    final item = _getSelectedActiveItem(selection, currentTimeMs);
    if (item == null) return const SizedBox.shrink();

    if (item is OverlayItem) {
      final currentX = _isDragging && _tempX != null ? _tempX! : (item.x.evaluate(currentTimeMs) ?? 0.0);
      final currentY = _isDragging && _tempY != null ? _tempY! : (item.y.evaluate(currentTimeMs) ?? 0.0);
      final currentW = _isDragging && _tempWidth != null ? _tempWidth! : (item.width.evaluate(currentTimeMs) ?? 1.0);
      final currentH = _isDragging && _tempHeight != null ? _tempHeight! : (item.height.evaluate(currentTimeMs) ?? 1.0);

      final left = currentX * w;
      final top = currentY * h;
      final width = currentW * w;
      final height = currentH * h;

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: _buildTransformHandles(
          item, 
          w, h, 
          currentX, currentY, currentW, currentH
        ),
      );
    } else if (item is FloatingTextItem) {
      final currentX = _isDragging && _tempX != null ? _tempX! : item.x.evaluate(currentTimeMs);
      final currentY = _isDragging && _tempY != null ? _tempY! : item.y.evaluate(currentTimeMs);
      
      final left = currentX * w;
      final top = currentY * h;
      
      return Positioned(
        left: left,
        top: top,
        child: _buildTextTransformHandles(item, w, h, currentX, currentY),
      );
    }

    return const SizedBox.shrink();
  }
  
  Widget _buildTemporaryArrow(double boardSize, double w, double h) {
    // A simple visual indicator for drawing arrow
    final double startX = (w - boardSize) / 2;
    final double startY = (h - boardSize) / 2;
    final squareSize = boardSize / 8;
    
    Offset getCenter(String sq) {
      int col = sq.codeUnitAt(0) - 97;
      int row = 8 - int.parse(sq[1]);
      return Offset(startX + (col + 0.5) * squareSize, startY + (row + 0.5) * squareSize);
    }
    
    final start = getCenter(_arrowStartSquare!);
    final end = getCenter(_arrowCurrentSquare!);
    
    return CustomPaint(
      painter: _TempArrowPainter(start, end),
    );
  }

  Widget _buildTextTransformHandles(FloatingTextItem item, double totalW, double totalH, double curX, double curY) {
    return GestureDetector(
      onPanStart: (_) {
        setState(() {
          _isDragging = true;
          _tempX = curX;
          _tempY = curY;
        });
      },
      onPanUpdate: (d) {
        setState(() {
          _tempX = (_tempX ?? curX) + (d.delta.dx / totalW);
          _tempY = (_tempY ?? curY) + (d.delta.dy / totalH);
        });
      },
      onPanEnd: (_) => _saveChanges(item),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accentBlue, width: 2),
        ),
        child: const Icon(Icons.drag_indicator, color: AppColors.accentBlue, size: 16),
      ),
    );
  }

  Widget _buildTransformHandles(OverlayItem item, double totalW, double totalH, double curX, double curY, double curW, double curH) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Center drag area
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (_) {
              setState(() {
                _isDragging = true;
                _tempX = curX;
                _tempY = curY;
              });
            },
            onPanUpdate: (d) {
              setState(() {
                _tempX = (_tempX ?? curX) + (d.delta.dx / totalW);
                _tempY = (_tempY ?? curY) + (d.delta.dy / totalH);
              });
            },
            onPanEnd: (_) => _saveChanges(item),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accentBlue, width: 2),
                color: AppColors.accentBlue.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        // Bottom Right Handle
        Positioned(
          right: -10,
          bottom: -10,
          child: GestureDetector(
            onPanStart: (_) {
              setState(() {
                _isDragging = true;
                _tempWidth = curW;
                _tempHeight = curH;
              });
            },
            onPanUpdate: (d) {
              setState(() {
                _tempWidth = (_tempWidth ?? curW) + (d.delta.dx / totalW);
                _tempHeight = (_tempHeight ?? curH) + (d.delta.dy / totalH);
              });
            },
            onPanEnd: (_) => _saveChanges(item),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle),
            ),
          ),
        ),
      ],
    );
  }
}

class _TempArrowPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  _TempArrowPainter(this.start, this.end);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentOrange.withValues(alpha: 0.8)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
    canvas.drawCircle(end, 10, paint);
  }
  
  @override
  bool shouldRepaint(covariant _TempArrowPainter old) => start != old.start || end != old.end;
}
