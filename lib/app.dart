import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/export_screen.dart';
import 'services/project_service.dart';
import 'services/render_service.dart';
import 'services/ffmpeg_service.dart';
import 'services/youtube_service.dart';

class ChessCreatorApp extends StatelessWidget {
  const ChessCreatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectService()),
        ChangeNotifierProvider(create: (_) => RenderService()),
        ChangeNotifierProvider(create: (_) => FfmpegService()),
        ChangeNotifierProvider(create: (_) => YouTubeService()),
      ],
      child: MaterialApp(
        title: 'ChessCreator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0D1117), // Background
          cardColor: const Color(0xFF161B22), // Surface
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF58A6FF), // AccentBlue
            surface: Color(0xFF161B22), // Surface
            surfaceContainerHighest: Color(0xFF21262D), // SurfaceLight
            outline: Color(0xFF30363D), // Border
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.dark().textTheme,
          ).apply(
            bodyColor: const Color(0xFFE6EDF3), // TextPrimary
            displayColor: const Color(0xFFE6EDF3), // TextPrimary
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF58A6FF),
              foregroundColor: const Color(0xFF0D1117),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/import': (context) => const ImportScreen(),
          '/editor': (context) => const EditorScreen(),
          '/export': (context) => const ExportScreen(),
        },
      ),
    );
  }
}
