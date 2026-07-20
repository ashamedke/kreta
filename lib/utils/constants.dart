import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color accentBlue = Color(0xFF58A6FF);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentGreen = Color(0xFF06D6A0);
  static const Color accentRed = Color(0xFFF85149);
  static const Color accentOrange = Color(0xFFD29922);
  static const Color boardLight = Color(0xFFF0D9B5);
  static const Color boardDark = Color(0xFFB58863);
}

class AppConstants {
  static const int defaultHoldMs = 2000;
  static const int defaultTransitionMs = 500;
  static const int defaultFps = 30;
}

class PieceSymbols {
  static const String whiteKing = '♔';
  static const String whiteQueen = '♕';
  static const String whiteRook = '♖';
  static const String whiteBishop = '♗';
  static const String whiteKnight = '♘';
  static const String whitePawn = '♙';
  
  static const String blackKing = '♚';
  static const String blackQueen = '♛';
  static const String blackRook = '♜';
  static const String blackBishop = '♝';
  static const String blackKnight = '♞';
  static const String blackPawn = '♟';

  static String getSymbol(String char) {
    switch (char) {
      case 'K': return whiteKing;
      case 'Q': return whiteQueen;
      case 'R': return whiteRook;
      case 'B': return whiteBishop;
      case 'N': return whiteKnight;
      case 'P': return whitePawn;
      case 'k': return blackKing;
      case 'q': return blackQueen;
      case 'r': return blackRook;
      case 'b': return blackBishop;
      case 'n': return blackKnight;
      case 'p': return blackPawn;
      default: return '';
    }
  }

  static bool isWhite(String char) {
    return char == char.toUpperCase();
  }
}
