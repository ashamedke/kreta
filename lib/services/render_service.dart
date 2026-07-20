import 'package:flutter/foundation.dart';
import 'package:chesscreator/models/project.dart';
import 'package:chesscreator/models/render_job.dart';

/// Service for managing the offline rendering process.
class RenderService extends ChangeNotifier {
  RenderJob? _currentJob;

  RenderJob? get currentJob => _currentJob;
  bool get isRendering => _currentJob != null && _currentJob!.status == RenderStatus.rendering;

  /// Initializes the render job. The actual rendering is driven by the UI.
  Future<void> startRender(Project project, RenderPreset preset, String outputDir, {int totalFrames = 0}) async {
    if (isRendering) {
      throw StateError('A render job is already in progress.');
    }
    
    _currentJob = RenderJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      projectId: project.id,
      preset: preset,
      totalFrames: totalFrames,
      currentFrame: 0,
      status: RenderStatus.rendering,
      outputPath: outputDir,
    );

    notifyListeners();
  }

  /// Updates the progress of the current job.
  void updateProgress(int frame) {
    if (_currentJob != null && _currentJob!.status == RenderStatus.rendering) {
      _currentJob = RenderJob(
        id: _currentJob!.id,
        projectId: _currentJob!.projectId,
        preset: _currentJob!.preset,
        totalFrames: _currentJob!.totalFrames,
        currentFrame: frame,
        status: _currentJob!.status,
        outputPath: _currentJob!.outputPath,
        errorMessage: _currentJob!.errorMessage,
        startedAt: _currentJob!.startedAt,
      );
      notifyListeners();
    }
  }

  /// Marks the render as completed.
  void completeRender(String outputPath) {
    if (_currentJob != null) {
      _currentJob = RenderJob(
        id: _currentJob!.id,
        projectId: _currentJob!.projectId,
        preset: _currentJob!.preset,
        totalFrames: _currentJob!.totalFrames,
        currentFrame: _currentJob!.currentFrame,
        status: RenderStatus.complete,
        outputPath: outputPath,
        errorMessage: _currentJob!.errorMessage,
        startedAt: _currentJob!.startedAt,
        completedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Marks the render as failed.
  void failRender(String error) {
    if (_currentJob != null) {
      _currentJob = RenderJob(
        id: _currentJob!.id,
        projectId: _currentJob!.projectId,
        preset: _currentJob!.preset,
        totalFrames: _currentJob!.totalFrames,
        currentFrame: _currentJob!.currentFrame,
        status: RenderStatus.failed,
        outputPath: _currentJob!.outputPath,
        errorMessage: error,
        startedAt: _currentJob!.startedAt,
        completedAt: _currentJob!.completedAt,
      );
      notifyListeners();
    }
  }

  /// Cancels the current render job.
  void cancelRender() {
    if (_currentJob != null) {
      _currentJob = RenderJob(
        id: _currentJob!.id,
        projectId: _currentJob!.projectId,
        preset: _currentJob!.preset,
        totalFrames: _currentJob!.totalFrames,
        currentFrame: _currentJob!.currentFrame,
        status: RenderStatus.idle,
        outputPath: _currentJob!.outputPath,
        errorMessage: _currentJob!.errorMessage,
        startedAt: _currentJob!.startedAt,
        completedAt: _currentJob!.completedAt,
      );
      notifyListeners();
    }
  }
}
