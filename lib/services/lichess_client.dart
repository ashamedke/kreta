import 'package:http/http.dart' as http;
import '../models/game.dart';
import 'chess_service.dart';

class LichessClient {
  final ChessService _chessService;

  LichessClient(this._chessService);

  /// Fetches a game from Lichess by its ID and returns a parsed Game object.
  Future<Game> fetchGameById(String gameId) async {
    final url = Uri.parse('https://lichess.org/game/export/$gameId?tags=true&clocks=false&evals=false&opening=false');
    final response = await http.get(url, headers: {
      'Accept': 'application/x-chess-pgn',
    });

    if (response.statusCode == 200) {
      final pgn = response.body;
      final game = _chessService.parseFromPgn(pgn);
      
      // Update source
      return Game(
        id: game.id,
        source: GameSource.lichess,
        sourceRef: gameId,
        startingFen: game.startingFen,
        pgnTags: game.pgnTags,
        plies: game.plies,
      );
    } else {
      throw Exception('Failed to fetch game from Lichess. Status: ${response.statusCode}');
    }
  }
}
