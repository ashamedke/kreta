import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:typed_data';

class AssetCacheService {
  static final AssetCacheService _instance = AssetCacheService._internal();
  factory AssetCacheService() => _instance;
  AssetCacheService._internal();

  ui.Image? boardImage;
  final Map<String, ui.Image> pieceImages = {};

  Future<void> init() async {
    try {
      boardImage = await _loadImage('assets/board/board.png');

      final map = {
        'P': 'w_pawn', 'N': 'w_knight', 'B': 'w_bishop', 'R': 'w_rook', 'Q': 'w_queen', 'K': 'w_king',
        'p': 'b_pawn', 'n': 'b_knight', 'b': 'b_bishop', 'r': 'b_rook', 'q': 'b_queen', 'k': 'b_king',
      };

      for (final entry in map.entries) {
        pieceImages[entry.key] = await _loadImage('assets/pieces/${entry.value}.png');
      }
      print("AssetCacheService initialized.");
    } catch (e) {
      print("Error loading assets: $e");
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }
}
