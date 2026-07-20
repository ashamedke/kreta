import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _selectedPath;
  bool _isValidating = false;
  String? _errorMessage;

  Future<void> _pickFfmpeg() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select FFmpeg Executable',
      type: FileType.custom,
      allowedExtensions: Platform.isWindows ? ['exe'] : [],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _selectedPath = path;
        _errorMessage = null;
      });
    }
  }

  Future<void> _validateAndSave() async {
    if (_selectedPath == null) return;
    
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final result = await Process.run(_selectedPath!, ['-version']);
      if (result.exitCode == 0 && result.stdout.toString().toLowerCase().contains('ffmpeg')) {
        // Valid FFmpeg, save it
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ffmpeg_path', _selectedPath!);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'The selected file does not appear to be a valid FFmpeg executable.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error executing file: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.video_settings, size: 64, color: AppColors.accentBlue),
                  const SizedBox(height: 24),
                  const Text(
                    'Setup FFmpeg',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ChessCreator requires FFmpeg to render videos. Please select the FFmpeg executable on your system to continue.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  InkWell(
                    onTap: _isValidating ? null : _pickFfmpeg,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.surfaceLight,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedPath ?? 'No file selected',
                              style: TextStyle(
                                color: _selectedPath == null ? AppColors.textSecondary : AppColors.textPrimary,
                                fontFamily: _selectedPath != null ? 'monospace' : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedPath != null)
                            const Icon(Icons.check_circle, color: AppColors.accentGreen),
                        ],
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.accentRed, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_selectedPath == null || _isValidating) ? null : _validateAndSave,
                      child: _isValidating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                            )
                          : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
