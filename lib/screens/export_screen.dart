import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/render_job.dart';

import '../services/ffmpeg_service.dart';
import '../services/project_service.dart';
import '../services/youtube_service.dart';
import '../widgets/render_progress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  Project? _project;
  String _selectedPresetName = 'HD (720p)';
  final _filenameController = TextEditingController();
  
  final List<RenderPreset> _presets = [
    RenderPreset( name: 'Preview (480p)', width: 854, height: 480, fps: 30, videoBitrate: 5000),
    RenderPreset( name: 'HD (720p)', width: 1280, height: 720, fps: 30, videoBitrate: 5000),
    RenderPreset( name: 'Full HD (1080p)', width: 1920, height: 1080, fps: 30, videoBitrate: 5000),
    RenderPreset( name: 'Full HD 60fps', width: 1920, height: 1080, fps: 60, videoBitrate: 5000),
    RenderPreset( name: '4K Ultra HD', width: 3840, height: 2160, fps: 60, videoBitrate: 5000),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_project == null) {
      _project = ModalRoute.of(context)!.settings.arguments as Project;
      _initDefaultPath();
    }
  }
  
  void _initDefaultPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    setState(() {
       _filenameController.text = '${docsDir.path}\\${_project!.name.replaceAll(' ', '_')}.mp4';
    });
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }
  
  void _pickOutputFile() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Video As',
      fileName: '${_project!.name.replaceAll(' ', '_')}.mp4',
      type: FileType.video,
      allowedExtensions: ['mp4'],
    );

    if (outputFile != null) {
      setState(() {
        _filenameController.text = outputFile;
      });
    }
  }

  void _pickBackgroundVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _project = _project!.copyWith(backgroundVideoPath: result.files.single.path);
      });
      context.read<ProjectService>().saveProject(_project!);
    }
  }

  void _pickBackgroundMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _project = _project!.copyWith(backgroundMusicPath: result.files.single.path);
      });
      context.read<ProjectService>().saveProject(_project!);
    }
  }


  void _startRender() async {
    final preset = _presets.firstWhere((p) => p.name == _selectedPresetName);
    final ffmpegService = context.read<FfmpegService>();
    
    if (!ffmpegService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FFmpeg is not available. Please install it to render videos.'), backgroundColor: Color(0xFFF85149)),
      );
      return;
    }

    if (_project!.backgroundVideoPath != null && !File(_project!.backgroundVideoPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Background video file not found: ${_project!.backgroundVideoPath}'), backgroundColor: Color(0xFFF85149)),
      );
      return;
    }

    if (_project!.backgroundMusicPath != null && !File(_project!.backgroundMusicPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Background music file not found: ${_project!.backgroundMusicPath}'), backgroundColor: Color(0xFFF85149)),
      );
      return;
    }

    final job = RenderJob(
      projectId: _project!.id,
      preset: preset,
      status: RenderStatus.preparing,
      currentFrame: 0,
      totalFrames: 100,
      outputPath: _filenameController.text,
    );

    // The RenderProgressDialog will handle starting and driving the render loop.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RenderProgressDialog(project: _project!, renderJob: job, onCancel: () {}),
    );
  }

  void _exportThumbnail() async {
    final preset = _presets.firstWhere((p) => p.name == _selectedPresetName);
    final job = RenderJob(
      projectId: _project!.id,
      preset: preset,
      status: RenderStatus.preparing,
      currentFrame: 0,
      totalFrames: 1,
      outputPath: _filenameController.text.replaceAll('.mp4', '.png'),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RenderProgressDialog(
        project: _project!, 
        renderJob: job, 
        isThumbnail: true,
        onCancel: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_project == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final hasFfmpeg = context.watch<FfmpegService>().isAvailable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Video'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Presets and Output
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quality Presets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _presets.map((preset) {
                      final isSelected = _selectedPresetName == preset.name;
                      return InkWell(
                        onTap: () => setState(() => _selectedPresetName = preset.name),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF58A6FF).withOpacity(0.1) : const Color(0xFF161B22),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(preset.name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF58A6FF) : const Color(0xFFE6EDF3))),
                              const SizedBox(height: 8),
                              Text('${preset.width}x${preset.height}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                              Text('${preset.fps} fps', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  const Text('Output Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _filenameController,
                          decoration: const InputDecoration(
                            labelText: 'Output Path',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.folder),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: _pickOutputFile,
                        tooltip: 'Browse',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Layout Style', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<LayoutType>(
                    value: _project!.layoutType,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                        value: LayoutType.splitScreen,
                        child: Text('Split Screen'),
                      ),
                      DropdownMenuItem(
                        value: LayoutType.pictureInPicture,
                        child: Text('Picture-in-Picture'),
                      ),
                    ],
                    onChanged: (LayoutType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _project = _project!.copyWith(layoutType: newValue);
                        });
                        context.read<ProjectService>().saveProject(_project!);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Background Video', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF30363D)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _project!.backgroundVideoPath ?? 'No video selected',
                            style: TextStyle(color: _project!.backgroundVideoPath != null ? const Color(0xFFE6EDF3) : const Color(0xFF8B949E)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_project!.backgroundVideoPath != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFFF85149)),
                          onPressed: () {
                            setState(() {
                              _project = _project!.clearBackgroundVideo();
                            });
                            context.read<ProjectService>().saveProject(_project!);
                          },
                          tooltip: 'Clear',
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.video_file),
                        label: const Text('Browse'),
                        onPressed: _pickBackgroundVideo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Background Music', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF30363D)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _project!.backgroundMusicPath ?? 'No music selected',
                            style: TextStyle(color: _project!.backgroundMusicPath != null ? const Color(0xFFE6EDF3) : const Color(0xFF8B949E)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_project!.backgroundMusicPath != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFFF85149)),
                          onPressed: () {
                            setState(() {
                              _project = _project!.clearBackgroundMusic();
                            });
                            context.read<ProjectService>().saveProject(_project!);
                          },
                          tooltip: 'Clear',
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.audio_file),
                        label: const Text('Browse'),
                        onPressed: _pickBackgroundMusic,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Ensure you have write permissions to the output folder.', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Right: Summary and Render Button
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Project Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Divider(height: 32, color: Color(0xFF30363D)),
                      _SummaryRow(label: 'Name', value: _project!.name),
                      _SummaryRow(label: 'Moves', value: '${_project!.game.plies.length ~/ 2}'),
                      _SummaryRow(label: 'Layers', value: '${_project!.timeline.layers.length}'),
                      
                      const SizedBox(height: 24),
                      if (!hasFfmpeg)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF85149).withOpacity(0.1),
                            border: Border.all(color: const Color(0xFFF85149)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFF85149)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'FFmpeg is not installed or not found in PATH. Rendering will fail.',
                                  style: TextStyle(color: Color(0xFFF85149)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF58A6FF), Color(0xFF7C3AED)],
                            ),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _startRender,
                            child: const Text(
                              'Render Video',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF58A6FF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _exportThumbnail,
                          child: const Text(
                            'Export Thumbnail (.png)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Consumer<YouTubeService>(
                        builder: (context, youtubeService, child) {
                          if (youtubeService.isUploading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF0000)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                final videoPath = _filenameController.text;
                                final thumbnailPath = videoPath.replaceAll('.mp4', '.png');
                                
                                await youtubeService.uploadVideo(
                                  videoPath: videoPath,
                                  thumbnailPath: thumbnailPath,
                                  title: _project!.name,
                                  description: 'Created with ChessCreator',
                                );
                                
                                if (youtubeService.uploadError != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Upload failed: ${youtubeService.uploadError}'), backgroundColor: const Color(0xFFF85149)),
                                  );
                                } else if (youtubeService.uploadedVideoId != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Uploaded to YouTube: ${youtubeService.uploadedVideoId}'), backgroundColor: const Color(0xFF238636)),
                                  );
                                }
                              },
                              icon: const Icon(Icons.cloud_upload, color: Color(0xFFFF0000)),
                              label: const Text(
                                'Upload to YouTube',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF0000)),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8B949E))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
