import 'dart:convert';
import 'package:chesscreator/services/chess_service.dart';
import 'package:chesscreator/services/lichess_client.dart';
import 'package:chesscreator/models/project.dart';

void main() async {
  try {
    print("Fetching game from lichess...");
    final client = LichessClient(ChessService());
    final game = await client.fetchGameById('n9g1s5k5');
    
    print("Game parsed successfully. Plies: \${game.plies.length}");
    
    print("Creating project...");
    final project = Project.create("Test Project", game);
    
    print("Project created. ID: \${project.id}");
    
    print("Testing JSON serialization...");
    final jsonString = jsonEncode(project.toJson());
    // print(jsonString);
    
    print("Testing JSON deserialization...");
    final projectDecoded = Project.fromJson(jsonDecode(jsonString));
    
    print("Deserialized successfully! Name: \${projectDecoded.name}");
    
  } catch (e, stack) {
    print("Error: \$e");
    print(stack);
  }
}
