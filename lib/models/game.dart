import 'package:uuid/uuid.dart';

enum GameSource { fen, pgn, chesscom, lichess }

/// Represents a single half-move in a chess game.
class Ply {
  /// 0-based ply number
  final int index;

  /// Standard algebraic notation, e.g. 'Nf3'
  final String moveSan;

  /// Origin square, e.g. 'e2'
  final String? fromSquare;

  /// Destination square, e.g. 'e4'
  final String? toSquare;

  /// Piece that was moved, e.g. 'P', 'N', 'B', etc.
  final String? pieceMoved;

  /// Piece that was captured, if any
  final String? capturedPiece;

  final bool isCheck;
  final bool isCheckmate;
  final bool isCastle;
  final bool isPromotion;
  final bool isEnPassant;

  /// FEN representation of the board after this ply
  final String resultingFen;

  /// Nullable override for default hold duration in ms
  final int? holdDurationMs;

  /// Nullable override for default transition duration in ms
  final int? transitionDurationMs;

  /// Nullable annotation, like '!!' or '?'
  final String? annotation;

  /// Characters per second override for typing effects
  final double? typingSpeedOverride;

  /// Manual toggle for 'important moment'
  final bool isFlagged;

  /// Arrows drawn on the board during this ply
  final List<BoardArrow> arrows;

  /// Floating text labels shown during this ply
  final List<FloatingText> floatingTexts;

  const Ply({
    required this.index,
    required this.moveSan,
    this.fromSquare,
    this.toSquare,
    this.pieceMoved,
    this.capturedPiece,
    required this.isCheck,
    required this.isCheckmate,
    required this.isCastle,
    required this.isPromotion,
    required this.isEnPassant,
    required this.resultingFen,
    this.holdDurationMs,
    this.transitionDurationMs,
    this.annotation,
    this.typingSpeedOverride,
    this.isFlagged = false,
    this.arrows = const [],
    this.floatingTexts = const [],
  });

  factory Ply.fromJson(Map<String, dynamic> json) {
    return Ply(
      index: json['index'] as int,
      moveSan: json['moveSan'] as String,
      fromSquare: json['fromSquare'] as String?,
      toSquare: json['toSquare'] as String?,
      pieceMoved: json['pieceMoved'] as String?,
      capturedPiece: json['capturedPiece'] as String?,
      isCheck: json['isCheck'] as bool? ?? false,
      isCheckmate: json['isCheckmate'] as bool? ?? false,
      isCastle: json['isCastle'] as bool? ?? false,
      isPromotion: json['isPromotion'] as bool? ?? false,
      isEnPassant: json['isEnPassant'] as bool? ?? false,
      resultingFen: json['resultingFen'] as String,
      holdDurationMs: json['holdDurationMs'] as int?,
      transitionDurationMs: json['transitionDurationMs'] as int?,
      annotation: json['annotation'] as String?,
      typingSpeedOverride: (json['typingSpeedOverride'] as num?)?.toDouble(),
      isFlagged: json['isFlagged'] as bool? ?? false,
      arrows: (json['arrows'] as List<dynamic>?)?.map((e) => BoardArrow.fromJson(e)).toList() ?? [],
      floatingTexts: (json['floatingTexts'] as List<dynamic>?)?.map((e) => FloatingText.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'moveSan': moveSan,
      'fromSquare': fromSquare,
      'toSquare': toSquare,
      'pieceMoved': pieceMoved,
      'capturedPiece': capturedPiece,
      'isCheck': isCheck,
      'isCheckmate': isCheckmate,
      'isCastle': isCastle,
      'isPromotion': isPromotion,
      'isEnPassant': isEnPassant,
      'resultingFen': resultingFen,
      'holdDurationMs': holdDurationMs,
      'transitionDurationMs': transitionDurationMs,
      'annotation': annotation,
      'typingSpeedOverride': typingSpeedOverride,
      'isFlagged': isFlagged,
      'arrows': arrows.map((e) => e.toJson()).toList(),
      'floatingTexts': floatingTexts.map((e) => e.toJson()).toList(),
    };
  }

  Ply copyWith({
    int? index,
    String? moveSan,
    String? fromSquare,
    String? toSquare,
    String? pieceMoved,
    String? capturedPiece,
    bool? isCheck,
    bool? isCheckmate,
    bool? isCastle,
    bool? isPromotion,
    bool? isEnPassant,
    String? resultingFen,
    int? holdDurationMs,
    int? transitionDurationMs,
    String? annotation,
    double? typingSpeedOverride,
    bool? isFlagged,
    List<BoardArrow>? arrows,
    List<FloatingText>? floatingTexts,
  }) {
    return Ply(
      index: index ?? this.index,
      moveSan: moveSan ?? this.moveSan,
      fromSquare: fromSquare ?? this.fromSquare,
      toSquare: toSquare ?? this.toSquare,
      pieceMoved: pieceMoved ?? this.pieceMoved,
      capturedPiece: capturedPiece ?? this.capturedPiece,
      isCheck: isCheck ?? this.isCheck,
      isCheckmate: isCheckmate ?? this.isCheckmate,
      isCastle: isCastle ?? this.isCastle,
      isPromotion: isPromotion ?? this.isPromotion,
      isEnPassant: isEnPassant ?? this.isEnPassant,
      resultingFen: resultingFen ?? this.resultingFen,
      holdDurationMs: holdDurationMs ?? this.holdDurationMs,
      transitionDurationMs: transitionDurationMs ?? this.transitionDurationMs,
      annotation: annotation ?? this.annotation,
      typingSpeedOverride: typingSpeedOverride ?? this.typingSpeedOverride,
      isFlagged: isFlagged ?? this.isFlagged,
      arrows: arrows ?? this.arrows,
      floatingTexts: floatingTexts ?? this.floatingTexts,
    );
  }
}

class BoardArrow {
  final String fromSquare;
  final String toSquare;
  final String color;
  final String? text;

  const BoardArrow({
    required this.fromSquare,
    required this.toSquare,
    this.color = '#ff0000',
    this.text,
  });

  factory BoardArrow.fromJson(Map<String, dynamic> json) {
    return BoardArrow(
      fromSquare: json['fromSquare'],
      toSquare: json['toSquare'],
      color: json['color'] ?? '#ff0000',
      text: json['text'],
    );
  }

  Map<String, dynamic> toJson() => {
    'fromSquare': fromSquare,
    'toSquare': toSquare,
    'color': color,
    'text': text,
  };
}

class FloatingText {
  final String text;
  final double x;
  final double y;
  final String color;
  final double fontSize;

  const FloatingText({
    required this.text,
    required this.x,
    required this.y,
    this.color = '#ffffff',
    this.fontSize = 24.0,
  });

  factory FloatingText.fromJson(Map<String, dynamic> json) {
    return FloatingText(
      text: json['text'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      color: json['color'] ?? '#ffffff',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'color': color,
    'fontSize': fontSize,
  };
}

/// Represents an entire chess game.
class Game {
  final String id;
  final GameSource source;
  final String? sourceRef;
  final Map<String, String> pgnTags;
  final String startingFen;
  final List<Ply> plies;
  final DateTime createdAt;

  Game({
    String? id,
    required this.source,
    this.sourceRef,
    required this.pgnTags,
    required this.startingFen,
    required this.plies,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String?,
      source: GameSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => GameSource.fen,
      ),
      sourceRef: json['sourceRef'] as String?,
      pgnTags: Map<String, String>.from(json['pgnTags'] as Map? ?? {}),
      startingFen: json['startingFen'] as String,
      plies: (json['plies'] as List? ?? [])
          .map((e) => Ply.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source.name,
      'sourceRef': sourceRef,
      'pgnTags': pgnTags,
      'startingFen': startingFen,
      'plies': plies.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Game copyWith({
    String? id,
    GameSource? source,
    String? sourceRef,
    Map<String, String>? pgnTags,
    String? startingFen,
    List<Ply>? plies,
    DateTime? createdAt,
  }) {
    return Game(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      pgnTags: pgnTags ?? this.pgnTags,
      startingFen: startingFen ?? this.startingFen,
      plies: plies ?? this.plies,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
