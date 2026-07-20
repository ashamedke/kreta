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
  final TextEditingController _pathController = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickFfmpeg() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select FFmpeg Executable',
      type: FileType.custom,
      allowedExtensions: Platform.isWindows ? ['exe'] : [],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pathController.text = result.files.single.path!;
        _errorMessage = null;
      });
    }
  }

  Future<void> _validateAndSave() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;
    
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final result = await Process.run(path, ['-version']);
      if (result.exitCode == 0 && result.stdout.toString().toLowerCase().contains('ffmpeg')) {
        // Valid FFmpeg, save it
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ffmpeg_path', path);
        
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pathController,
                          enabled: !_isValidating,
                          decoration: InputDecoration(
                            hintText: 'e.g. C:\\ffmpeg\\bin\\ffmpeg.exe or just ffmpeg',
                            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            prefixIcon: const Icon(Icons.code, color: AppColors.textSecondary),
                          ),
                          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace'),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _isValidating ? null : _pickFfmpeg,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Browse'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          backgroundColor: AppColors.surfaceLight,
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ],
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
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _pathController,
                      builder: (context, value, child) {
                        return ElevatedButton(
                          onPressed: (value.text.trim().isEmpty || _isValidating) ? null : _validateAndSave,
                          child: _isValidating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                                )
                              : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        );
                      },
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
