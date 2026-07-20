import 'package:chesscreator/services/chess_service.dart';

void main() {
  final pgn = """[Event "casual rapid game"]
[Site "https://lichess.org/n9g1s5k5"]
[Date "2026.07.16"]
[Round "-"]
[White "dc_blunders"]
[Black "karachun1"]
[Result "1-0"]
[GameId "n9g1s5k5"]
[UTCDate "2026.07.16"]
[UTCTime "15:14:41"]
[WhiteElo "1868"]
[BlackElo "1835"]
[Variant "Standard"]
[TimeControl "600+0"]
[ECO "A53"]
[Opening "Old Indian Defense: Czech Variation, with Nc3"]
[Termination "Normal"]

1. d4 d6 2. c4 c6 3. Nc3 Nf6 4. Nf3 h6 5. e4 Qa5 6. Bd2 Qc7 7. Be2 e5 8. d5 Be7 9. O-O O-O 10. Rb1 Re8 11. Qc2 Nbd7 12. b4 a6 13. a4 b6 14. h3 Bb7 15. Rfc1 Rab8 16. Bd3 Bf8 17. b5 cxd5 18. Nxd5 Nxd5 19. cxd5 Qxc2 20. Rxc2 Nc5 21. Ne1 Nxd3 22. Nxd3 Rec8 23. Rbc1 a5 24. Rxc8 Rxc8 25. Rxc8 Bxc8 26. Nb2 f5 27. f3 fxe4 28. fxe4 1-0""";
  
  try {
    final game = ChessService().parseFromPgn(pgn);
    print(game.plies.length);
  } catch (e, stack) {
    print(e);
    print(stack);
  }
}
