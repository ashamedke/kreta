import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/asset_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AssetCacheService().init();
  
  final prefs = await SharedPreferences.getInstance();
  final ffmpegPath = prefs.getString('ffmpeg_path');
  
  bool isValidFfmpeg = false;
  if (ffmpegPath != null && File(ffmpegPath).existsSync()) {
    try {
      final result = await Process.run(ffmpegPath, ['-version']);
      if (result.exitCode == 0 && result.stdout.toString().toLowerCase().contains('ffmpeg')) {
        isValidFfmpeg = true;
      }
    } catch (e) {
      // Ignore execution errors, treat as invalid
    }
  }

  runApp(ChessCreatorApp(initialRouteIsSetup: !isValidFfmpeg));
}
