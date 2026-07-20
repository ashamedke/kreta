import 'package:flutter/material.dart';
import 'app.dart';
import 'services/asset_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AssetCacheService().init();
  runApp(const ChessCreatorApp());
}
