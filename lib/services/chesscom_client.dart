import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import 'chess_service.dart';

class ChesscomClient {
  final ChessService _chessService;

  ChesscomClient(this._chessService);

  /// Fetches a game from Chess.com by searching the user's monthly archive.
  /// Example url: https://www.chess.com/game/live/123456789
  Future<Game> fetchGameByUrl(String url) async {
    // A robust implementation would need the user's username to query the archive.
    // For V1 MVP, if we don't have the username, we might not be able to easily fetch by just Game ID 
    // since the API is structured by user archives.
    // Let's assume the user inputs the direct PGN or we use a username/month approach.
    
    // Instead of parsing the URL, for this simple client we'll fetch the latest game of a given username.
    throw UnimplementedError('Fetching by URL requires username for chess.com API. Use fetchLatestGameForUser instead.');
  }
  
  Future<Game> fetchLatestGameForUser(String username) async {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    
    final url = Uri.parse('https://api.chess.com/pub/player/$username/games/$year/$month');
    final response = await http.get(url, headers: {
      'User-Agent': 'ChessCreator App (drnew)',
    });

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final games = json['games'] as List;
      
      if (games.isEmpty) {
        throw Exception('No games found for $username in $year-$month');
      }
      
      final latestGame = games.last;
      final pgn = latestGame['pgn'] as String;
      
      final game = _chessService.parseFromPgn(pgn);
      
      return Game(
        id: game.id,
        source: GameSource.chesscom,
        sourceRef: latestGame['url'],
        startingFen: game.startingFen,
        pgnTags: game.pgnTags,
        plies: game.plies,
      );
    } else {
      throw Exception('Failed to fetch from chess.com. Status: ${response.statusCode}');
    }
  }
}
