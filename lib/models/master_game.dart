class MasterGame {
  final int gameId;
  final String white;
  final String black;
  final String event;
  final String date;
  final String result;
  final int whiteElo;
  final int blackElo;
  final int moveCount;
  final List<GameMove> moves;

  MasterGame({
    required this.gameId,
    required this.white,
    required this.black,
    required this.event,
    required this.date,
    required this.result,
    required this.whiteElo,
    required this.blackElo,
    required this.moveCount,
    required this.moves,
  });

  factory MasterGame.fromJson(Map<String, dynamic> json) {
    return MasterGame(
      gameId: json['game_id'] as int,
      white: json['white'] as String? ?? 'Unknown',
      black: json['black'] as String? ?? 'Unknown',
      event: json['event'] as String? ?? 'Unknown',
      date: json['date'] as String? ?? 'Unknown',
      result: json['result'] as String? ?? '*',
      whiteElo: json['white_elo'] is int
          ? json['white_elo']
          : int.tryParse(json['white_elo']?.toString() ?? '0') ?? 0,
      blackElo: json['black_elo'] is int
          ? json['black_elo']
          : int.tryParse(json['black_elo']?.toString() ?? '0') ?? 0,
      moveCount: json['move_count'] as int,
      moves: json['moves'] != null
          ? (json['moves'] as List<dynamic>)
              .map((m) => GameMove.fromJson(m as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  int get averageElo => ((whiteElo + blackElo) / 2).round();

  String get gameTitle => '$white vs $black';
}

class GameMove {
  final String san;
  final String uci;
  final String fenBefore;
  final String fenAfter;

  GameMove({
    required this.san,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
  });

  factory GameMove.fromJson(Map<String, dynamic> json) {
    return GameMove(
      san: json['san'] as String,
      uci: json['uci'] as String,
      fenBefore: json['fen_before'] as String,
      fenAfter: json['fen_after'] as String,
    );
  }

  String get fromSquare => uci.substring(0, 2);
  String get toSquare => uci.substring(2, 4);
}
