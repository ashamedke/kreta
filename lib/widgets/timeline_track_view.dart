import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/timeline.dart';
import '../controllers/timeline_controller.dart';
import '../utils/constants.dart';
import '../models/selection_model.dart';
import '../services/ffmpeg_service.dart';
import '../services/audio_waveform_service.dart';
import 'audio_waveform_painter.dart';

class TimelineTrackView extends StatelessWidget {
  final Track track;
  final TimelineController controller;
  final double trackHeight;

  const TimelineTrackView({
    super.key,
    required this.track,
    required this.controller,
    this.trackHeight = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: trackHeight,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: track.items.map((item) {
           final left = item.startTimeMs * controller.pixelsPerMs;
           final width = ((item.endTimeMs ?? (item.startTimeMs + 2000)) - item.startTimeMs) * controller.pixelsPerMs;
           
           return Positioned(
             left: left,
             width: width,
             height: trackHeight,
             child: _buildItemContent(context, item),
           );
        }).toList(),
      ),
    );
  }

  Widget _buildItemContent(BuildContext context, TimelineItem item) {
    Color bgColor = AppColors.surfaceLight;
    String label = 'Item';
    
    if (item is ChessMoveItem) {
      bgColor = AppColors.accentBlue.withValues(alpha: 0.5);
      label = 'Move ${item.plyIndex}';
    } else if (item is OverlayItem) {
      bgColor = AppColors.accentPurple.withValues(alpha: 0.5);
      label = item.assetPath.split(RegExp(r'[\\/]')).last;
    } else if (item is ArrowItem) {
      bgColor = AppColors.accentOrange.withValues(alpha: 0.5);
      label = '${item.fromSquare} â†’ ${item.toSquare}';
    } else if (item is FloatingTextItem) {
      bgColor = AppColors.accentRed.withValues(alpha: 0.5);
      label = item.text;
    }
    
    if (item is AudioItem) {
      final ffmpegService = context.watch<FfmpegService>();
      final waveformService = AudioWaveformService();
      final selectionModel = context.watch<SelectionModel>();
      final isSelected = selectionModel.selectedItemId == item.id;
      
      return GestureDetector(
        onTap: () => selectionModel.selectItem(item.id),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? AppColors.accentBlue : AppColors.border, width: isSelected ? 2 : 1),
          ),
          child: FutureBuilder<Float32List?>(
          future: waveformService.getWaveform(item.assetPath, ffmpegService),
          builder: (context, snapshot) {
            Widget content = const Center(
              child: Icon(Icons.audiotrack, size: 16, color: AppColors.textSecondary),
            );
            
            if (snapshot.hasData && snapshot.data != null) {
              content = CustomPaint(
                painter: AudioWaveformPainter(
                  peaks: snapshot.data!,
                  pixelsPerMs: controller.pixelsPerMs,
                  startTimeMs: item.startTimeMs,
                  endTimeMs: item.endTimeMs,
                  color: AppColors.accentRed.withValues(alpha: 0.8),
                ),
                child: Container(),
              );
            }
            
            return Stack(
              children: [
                content,
                Positioned(
                  left: 4, top: 4,
                  child: Text(
                    item.assetPath.split(RegExp(r'[\\/]')).last,
                    style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, shadows: [
                      Shadow(color: Colors.black, blurRadius: 2)
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
        ),
      );
    }
    
    final selectionModel = context.watch<SelectionModel>();
    final isSelected = selectionModel.selectedItemId == item.id;

    Widget childWidget = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isSelected ? AppColors.accentBlue : AppColors.border, width: isSelected ? 2 : 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textPrimary),
          overflow: TextOverflow.clip,
          softWrap: false,
        ),
      ),
    );
    
    return GestureDetector(
      onTap: () => selectionModel.selectItem(item.id),
      child: childWidget,
    );
  }
}
