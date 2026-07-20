import 'package:flutter/material.dart';
import '../utils/constants.dart';

import '../models/timing.dart';
import '../models/project.dart';
import '../services/timing_resolver.dart';

class TimelineEditor extends StatefulWidget {
  final Project project;
  final List<ResolvedTiming> resolvedTimings;
  final int currentPlyIndex;
  final ValueChanged<int> onPlySelected;
  final ValueChanged<TimingRules> onTimingChanged;

  const TimelineEditor({
    super.key,
    required this.project,
    required this.resolvedTimings,
    required this.currentPlyIndex,
    required this.onPlySelected,
    required this.onTimingChanged,
  });

  @override
  State<TimelineEditor> createState() => _TimelineEditorState();
}

class _TimelineEditorState extends State<TimelineEditor> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    double totalDurationMs = 0;
    for (var t in widget.resolvedTimings) {
      totalDurationMs += (t.holdDurationMs + t.transitionDurationMs);
    }

    return Container(
      height: 120,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Timeline', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                Text(
                  'Total Duration: ${(totalDurationMs / 1000).toStringAsFixed(1)}s',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.project.game.plies.length,
              itemBuilder: (context, index) {
                final ply = widget.project.game.plies[index];
                final timing = widget.resolvedTimings.length > index ? widget.resolvedTimings[index] : null;
                final duration = timing != null ? timing.holdDurationMs + timing.transitionDurationMs : 2000;
                
                final width = (duration / 100).clamp(40.0, 300.0);
                final isSelected = index == widget.currentPlyIndex;

                Color blockColor = AppColors.surface;
                if (ply.moveSan.contains('#')) {
                  blockColor = AppColors.accentPurple;
                } else if (ply.moveSan.contains('+')) {
                  blockColor = AppColors.accentRed;
                } else if (ply.moveSan.contains('x')) {
                  blockColor = AppColors.accentOrange;
                }

                return GestureDetector(
                  onTap: () => widget.onPlySelected(index),
                  child: Container(
                    width: width,
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(4),
                      border: isSelected ? Border.all(color: AppColors.accentBlue, width: 2) : Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        ply.moveSan,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
