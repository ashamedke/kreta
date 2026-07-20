import 'package:chess/chess.dart' as chess_lib;
import 'package:chesscreator/models/game.dart';

/// Service to parse FEN and PGN into our domain Game model.
class ChessService {
  /// Validates FEN and creates a single-position Game (no plies).
  Game parseFromFen(String fen) {
    final chess = chess_lib.Chess();
    if (!chess.load(fen)) {
      throw FormatException('Invalid FEN string: $fen');
    }

    return Game(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: GameSource.fen,
      pgnTags: const {},
      startingFen: fen,
      plies: [],
      
      
    );
  }

  /// Parses PGN movetext, replays through chess engine to generate full Ply list.
  Game parseFromPgn(String pgn) {
    final chess = chess_lib.Chess();
    if (!chess.load_pgn(pgn)) {
      throw FormatException('Invalid PGN string or could not load PGN');
    }

    // Extract tags
    final tags = chess.header;
    final startingFen = tags['FEN'] ?? chess_lib.Chess.DEFAULT_POSITION;
    
    // To get the resulting FEN after each move, we must replay the moves from the initial position.
    final replayChess = chess_lib.Chess();
    if (tags.containsKey('FEN')) {
       replayChess.load(startingFen);
    }

    // chess.history returns a list of maps containing move details.
    final history = chess.history;
    final plies = <Ply>[];

    for (int i = 0; i < history.length; i++) {
      final moveData = history[i] as Map<String, dynamic>;
      
      final fromSquare = moveData['from'] as String;
      final toSquare = moveData['to'] as String;
      final piece = moveData['piece'] as String;
      final san = moveData['san'] as String;
      final flags = moveData['flags'] as String;
      
      final capturedPiece = moveData['captured'] as String?;
      
      // Execute move on the replay board to get the resulting fen and check status
      replayChess.move(moveData);

      final isCheck = replayChess.in_check;
      final isCheckmate = replayChess.in_checkmate;
      
      final isCastle = flags.contains('k') || flags.contains('q');
      final isPromotion = flags.contains('p');
      final isEnPassant = flags.contains('e');
      
      plies.add(
        Ply(
          index: i,
          moveSan: san,
          fromSquare: fromSquare,
          toSquare: toSquare,
          pieceMoved: piece,
          capturedPiece: capturedPiece,
          isCheck: isCheck,
          isCheckmate: isCheckmate,
          isCastle: isCastle,
          isPromotion: isPromotion,
          isEnPassant: isEnPassant,
          resultingFen: replayChess.fen,
        )
      );
    }

    return Game(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: GameSource.pgn,
      pgnTags: Map<String, String>.from(tags),
      startingFen: startingFen,
      plies: plies,
      
      
    );
  }
}
