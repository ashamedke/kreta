import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chesscreator/services/chess_service.dart';
import 'package:chesscreator/models/project.dart';

void main() async {
  try {
    print("Fetching games for dc_blunders...");
    final url = Uri.parse('https://lichess.org/api/games/user/dc_blunders?max=5');
    final response = await http.get(url, headers: {'Accept': 'application/x-chess-pgn'});
    
    // Split by multiple newlines (PGN standard separates games by empty lines)
    final pgns = response.body.split(RegExp(r'\n\n\n+'));
    final chessService = ChessService();
    
    for (var i = 0; i < pgns.length; i++) {
      final pgn = pgns[i].trim();
      if (pgn.isEmpty) continue;
      
      print('Parsing Game \${i + 1}...');
      final game = chessService.parseFromPgn(pgn);
      print('Parsed \${game.plies.length} plies.');
      
      final project = Project.create("Test Project \$i", game);
      final json = project.toJson();
      Project.fromJson(json); // Test roundtrip
      print('Project \${i + 1} created and serialized successfully.');
    }
    
    print('All tests passed!');
  } catch (e, stack) {
    print("Error: \$e");
    print(stack);
  }
}
