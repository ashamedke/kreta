import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/project.dart';
import '../controllers/timeline_controller.dart';
import 'timeline_track_view.dart';

class TimelineEditor extends StatefulWidget {
  final Project project;
  final double currentRealtimeMs;
  final ValueChanged<double> onSeek;

  const TimelineEditor({
    super.key,
    required this.project,
    required this.currentRealtimeMs,
    required this.onSeek,
  });

  @override
  State<TimelineEditor> createState() => _TimelineEditorState();
}

class _TimelineEditorState extends State<TimelineEditor> {
  final TimelineController _controller = TimelineController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(TimelineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Optionally auto-scroll if playhead moves out of view
    final playheadX = widget.currentRealtimeMs * _controller.pixelsPerMs;
    if (playheadX > _scrollController.offset + MediaQuery.of(context).size.width || 
        playheadX < _scrollController.offset) {
      if (_scrollController.hasClients) {
         _scrollController.jumpTo((playheadX - 100).clamp(0.0, _scrollController.position.maxScrollExtent));
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {}); // Rebuild when zoom changes
  }

  void _onScrollChanged() {
    _controller.updateScrollOffset(_scrollController.offset);
  }

  void _handleTap(TapUpDetails details) {
    final tapX = details.localPosition.dx;
    final timeMs = tapX / _controller.pixelsPerMs;
    widget.onSeek(timeMs);
  }

  @override
  Widget build(BuildContext context) {
    // Total width is based on the end of the last item, or a default large width.
    double maxTimeMs = 60000; // Default 1 minute
    for (final track in widget.project.timeline.tracks) {
       for (final item in track.items) {
          final end = item.endTimeMs ?? (item.startTimeMs + 2000);
          if (end > maxTimeMs) maxTimeMs = end.toDouble();
       }
    }
    
    // Add padding to the end
    maxTimeMs += 5000;
    
    final canvasWidth = maxTimeMs * _controller.pixelsPerMs;
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar (Zoom controls)
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                const Text('Timeline', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.zoom_out, size: 16), color: AppColors.textSecondary, onPressed: _controller.zoomOut, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 12),
                IconButton(icon: const Icon(Icons.zoom_in, size: 16), color: AppColors.textSecondary, onPressed: _controller.zoomIn, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Track Headers (Left Panel)
                Container(
                  width: 120,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: ListView(
                    children: widget.project.timeline.tracks.map((track) {
                      return Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                        child: Text(track.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, overflow: TextOverflow.ellipsis)),
                      );
                    }).toList(),
                  ),
                ),
                
                // Track Canvas (Right Panel)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: GestureDetector(
                      onTapUp: _handleTap,
                      child: SizedBox(
                        width: canvasWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Tracks
                            Column(
                              children: widget.project.timeline.tracks.map((track) {
                                return TimelineTrackView(track: track, controller: _controller);
                              }).toList(),
                            ),
                            
                            // Playhead
                            Positioned(
                              left: widget.currentRealtimeMs * _controller.pixelsPerMs,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: AppColors.accentRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
