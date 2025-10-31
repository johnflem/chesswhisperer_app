import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ChessGameScreen(),
    );
  }
}

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  String? sessionId;
  Map<String, String> board = {};
  List<String> legalMoves = [];
  List<Map<String, dynamic>> legalMovesDetailed = []; // NEW: Detailed move info
  String currentPlayer = 'white';
  String gameStatus = 'active';
  bool inCheck = false;
  List<String> moveHistory = [];
  List<Map<String, dynamic>>? moveDetails;
  String playerColor = 'white';
  int aiDifficulty = 1;
  String? selectedSquare;
  String? highlightedSquare;
  List<String> possibleMoves = [];
  List<String> dangerousMoves = []; // Moves where piece can be immediately captured
  List<String> piecesUnderAttack = []; // NEW: Pieces threatened by opponent
  bool isLoading = false;
  bool isAIThinking = false;
  Map<String, dynamic>? lastMove;
  String? suggestedMove;
  String? moveExplanation;
  bool? isDbMove; // NEW: Indicates if suggested move is from opening book
  Map<String, List<String>> capturedPieces = {
    'white': [],
    'black': [],
  };
  
  final String apiUrl = 'https://fleminganalytic.com/chess';

  @override
  void initState() {
    super.initState();
    startNewGame();
  }

  Future<void> startNewGame() async {
    setState(() {
      isLoading = true;
      gameStatus = 'active';
      moveHistory = [];
      capturedPieces = {'white': [], 'black': []};
      selectedSquare = null;
      highlightedSquare = null;
      possibleMoves = [];
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/new_game'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player_color': playerColor,
          'ai_difficulty': aiDifficulty,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        sessionId = data['session_id'];
        await updateGameState();
        
        if (!mounted) return;
        showMessage('New game started!', MessageType.success);
        
        // If player chose black, make AI move first
        if (playerColor == 'black' && currentPlayer == 'white') {
          await Future.delayed(const Duration(milliseconds: 500));
          await makeAIMove();
        }
      } else {
        showError('Failed to start new game');
      }
    } catch (e) {
      showError('Error connecting to server: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> updateGameState() async {
    if (sessionId == null) return;

    try {
      final stateResponse = await http.get(
        Uri.parse('$apiUrl/game_state/$sessionId'),
      );

      if (stateResponse.statusCode == 200) {
        final data = jsonDecode(stateResponse.body);
        final boardFen = data['board_fen'] as String;
        
        setState(() {
          board = parseFEN(boardFen);
          currentPlayer = data['current_player'];
          inCheck = data['in_check'] ?? false;
          moveHistory = List<String>.from(data['move_history'] ?? []);
          moveDetails = data['move_details'] != null
              ? List<Map<String, dynamic>>.from(data['move_details'])
              : null;
          lastMove = data['last_move'];
          suggestedMove = data['suggested_next_move'];
          moveExplanation = data['move_explanation'];
          // NEW: Get pieces under attack from game state
          piecesUnderAttack = data['pieces_under_attack'] != null
              ? List<String>.from(data['pieces_under_attack'])
              : [];
        });

        updateCapturedPieces();

        // Show check notification if current player is in check
        if (inCheck && gameStatus == 'active') {
          // Delay slightly so the message appears after the board updates
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && inCheck) {
              if (currentPlayer == playerColor) {
                showMessage('You are in CHECK! Protect your King!', MessageType.error);
              } else {
                showMessage('$currentPlayer is in CHECK!', MessageType.info);
              }
            }
          });
        }

        final movesResponse = await http.get(
          Uri.parse('$apiUrl/legal_moves/$sessionId'),
        );

        if (movesResponse.statusCode == 200) {
          final movesData = jsonDecode(movesResponse.body);
          setState(() {
            legalMoves = List<String>.from(movesData['legal_moves'] ?? []);
            // NEW: Get detailed legal moves with protection info
            legalMovesDetailed = movesData['legal_moves_detailed'] != null
                ? List<Map<String, dynamic>>.from(
                    (movesData['legal_moves_detailed'] as List)
                        .map((e) => Map<String, dynamic>.from(e)))
                : [];
          });
        }
      }
    } catch (e) {
      showError('Error updating game state: $e');
    }
  }

  Map<String, String> parseFEN(String fen) {
    final rows = fen.split(' ')[0].split('/');
    final Map<String, String> board = {};
    
    for (int r = 0; r < 8; r++) {
      int file = 0;
      for (int i = 0; i < rows[r].length; i++) {
        final c = rows[r][i];
        if (int.tryParse(c) != null) {
          file += int.parse(c);
        } else {
          final square = String.fromCharCode(97 + file) + (8 - r).toString();
          board[square] = c;
          file++;
        }
      }
    }
    return board;
  }

  void updateCapturedPieces() {
    // Calculate captured pieces by comparing initial set to current board
    final initial = {
      'white': ['P','P','P','P','P','P','P','P','R','R','N','N','B','B','Q','K'],
      'black': ['p','p','p','p','p','p','p','p','r','r','n','n','b','b','q','k']
    };
    
    final current = {'white': <String>[], 'black': <String>[]};
    for (final piece in board.values) {
      if ('PRNBQK'.contains(piece)) {
        current['white']!.add(piece);
      }
      if ('prnbqk'.contains(piece)) {
        current['black']!.add(piece);
      }
    }
    
    List<String> diff(List<String> start, List<String> now) {
      final copy = List<String>.from(now);
      return start.where((x) {
        final idx = copy.indexOf(x);
        if (idx != -1) {
          copy.removeAt(idx);
          return false;
        }
        return true;
      }).toList();
    }
    
    setState(() {
      capturedPieces['white'] = diff(initial['black']!, current['black']!);
      capturedPieces['black'] = diff(initial['white']!, current['white']!);
    });
  }

  Future<void> makeMove(String from, String to) async {
    if (sessionId == null) return;

    try {
      String move = from + to;
      
      final piece = board[from];
      
      // Detect castling: King moving 2 squares horizontally
      if (piece != null && piece.toLowerCase() == 'k') {
        final fromFile = from.codeUnitAt(0) - 97; // a=0, h=7
        final toFile = to.codeUnitAt(0) - 97;
        final fileDiff = (toFile - fromFile).abs();
        
        if (fileDiff == 2) {
          // This is castling! Convert to proper notation
          if (toFile > fromFile) {
            // Kingside castling
            move = 'O-O';
          } else {
            // Queenside castling
            move = 'O-O-O';
          }
        }
      }
      
      // Check if promotion is needed (only for non-castling moves)
      if (move != 'O-O' && move != 'O-O-O') {
        final isPromotion = (piece == 'P' && to[1] == '8') || (piece == 'p' && to[1] == '1');
        
        if (isPromotion) {
          final promotionPiece = await showPromotionDialog();
          if (promotionPiece == null) return; // User cancelled
          move += promotionPiece;
        }
      }

      final response = await http.post(
        Uri.parse('$apiUrl/make_move'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'move': move,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await updateGameState();

        // Check for check (but not checkmate)
        if (data['check'] == true && data['checkmate'] != true) {
          showMessage('Check!', MessageType.error);
        }

        // ALWAYS manually move the rook when castling
        if (move == 'O-O' || move == 'O-O-O') {
          print('DEBUG: Castling detected: $move');
          print('DEBUG: playerColor = $playerColor');
          print('DEBUG: Board before rook move: $board');
          
          final isWhite = playerColor == 'white';
          final rookFrom = move == 'O-O' ? (isWhite ? 'h1' : 'h8') : (isWhite ? 'a1' : 'a8');
          final rookTo = move == 'O-O' ? (isWhite ? 'f1' : 'f8') : (isWhite ? 'd1' : 'd8');
          
          print('DEBUG: Looking for rook at: $rookFrom');
          print('DEBUG: Rook piece at $rookFrom: ${board[rookFrom]}');
          print('DEBUG: Should move rook to: $rookTo');
          
          // Find the rook - it might still be at original position OR might have been moved somewhere else by backend
          String? actualRookLocation;
          final rookSymbol = isWhite ? 'R' : 'r';
          
          // First check original position
          if (board[rookFrom] == rookSymbol) {
            actualRookLocation = rookFrom;
          } else {
            // Look for the rook on the back rank (it might have been moved by backend)
            final backRank = isWhite ? '1' : '8';
            for (final square in board.keys) {
              if (square.endsWith(backRank) && board[square] == rookSymbol) {
                // Could be the rook we're looking for
                // For queenside, rook should be on a-d files
                // For kingside, rook should be on f-h files
                final file = square[0];
                if (move == 'O-O-O' && 'abcd'.contains(file)) {
                  actualRookLocation = square;
                  break;
                } else if (move == 'O-O' && 'fgh'.contains(file)) {
                  actualRookLocation = square;
                  break;
                }
              }
            }
          }
          
          print('DEBUG: Found rook at: $actualRookLocation');
          
          if (actualRookLocation != null && actualRookLocation != rookTo) {
            setState(() {
              final rook = board[actualRookLocation];
              board.remove(actualRookLocation);
              if (rook != null) {
                board[rookTo] = rook;
                print('DEBUG: Moved rook from $actualRookLocation to $rookTo');
              }
            });
          } else if (actualRookLocation == null) {
            print('DEBUG: ERROR - Could not find rook!');
          } else {
            print('DEBUG: Rook already at correct position');
          }
          
          print('DEBUG: Board after rook move: $board');
        }
        
        if (data['game_over'] == true) {
          setState(() {
            gameStatus = 'finished';
          });
          showGameResult(data);
        } else if (currentPlayer != playerColor && gameStatus == 'active') {
          await Future.delayed(const Duration(milliseconds: 500));
          await makeAIMove();
        }
      } else {
        final data = jsonDecode(response.body);
        showError(data['error'] ?? 'Invalid move');
      }
    } catch (e) {
      showError('Error making move: $e');
    }
  }

  Future<void> makeAIMove() async {
    if (sessionId == null || gameStatus != 'active') return;

    setState(() {
      isAIThinking = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      
      final response = await http.post(
        Uri.parse('$apiUrl/get_ai_move'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': sessionId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // NEW: Check if AI used a book move
        if (data['is_db_move'] == true) {
          showMessage('AI played an opening book move', MessageType.info);
        }

        await updateGameState();

        // Check for check (but not checkmate) after AI move
        if (data['check'] == true && data['checkmate'] != true) {
          showMessage('Check! AI put you in check!', MessageType.error);
        }

        if (data['game_over'] == true) {
          setState(() {
            gameStatus = 'finished';
          });
          showGameResult(data);
        }
      }
    } catch (e) {
      showError('Error getting AI move: $e');
    } finally {
      if (mounted) {
        setState(() {
          isAIThinking = false;
        });
      }
    }
  }

  void showError(String message) {
    if (!mounted) return;
    showMessage(message, MessageType.error);
  }

  void showMessage(String message, MessageType type) {
    if (!mounted) return;
    
    final colors = {
      MessageType.info: Colors.blue,
      MessageType.success: Colors.green,
      MessageType.error: Colors.red,
    };
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colors[type],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void onSquareTap(String square) {
    if (gameStatus != 'active' || currentPlayer != playerColor) return;

    final piece = board[square];

    if (selectedSquare == null) {
      // Select a piece
      if (piece != null && isPieceOwnedByPlayer(piece)) {
        setState(() {
          selectedSquare = square;
          possibleMoves = getPossibleMovesFromDetailed(square);
          dangerousMoves = getDangerousMovesFromDetailed(square);
        });
      }
    } else {
      // Try to move or reselect
      if (possibleMoves.contains(square)) {
        makeMove(selectedSquare!, square);
        setState(() {
          selectedSquare = null;
          possibleMoves = [];
          dangerousMoves = [];
        });
      } else if (piece != null && isPieceOwnedByPlayer(piece)) {
        setState(() {
          selectedSquare = square;
          possibleMoves = getPossibleMovesFromDetailed(square);
          dangerousMoves = getDangerousMovesFromDetailed(square);
        });
      } else {
        setState(() {
          selectedSquare = null;
          possibleMoves = [];
          dangerousMoves = [];
        });
      }
    }
  }

  void onSquareLongPress(String square) {
    if (gameStatus != 'active' || currentPlayer != playerColor) return;

    final piece = board[square];
    if (piece != null && isPieceOwnedByPlayer(piece)) {
      setState(() {
        highlightedSquare = square;
        possibleMoves = getPossibleMovesFromDetailed(square);
        dangerousMoves = getDangerousMovesFromDetailed(square);
      });

      // Clear highlight after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            if (highlightedSquare == square) {
              highlightedSquare = null;
              if (selectedSquare != square) {
                possibleMoves = [];
              }
            }
          });
        }
      });
    }
  }

  bool isPieceOwnedByPlayer(String piece) {
    if (playerColor == 'white') {
      return piece == piece.toUpperCase();
    } else {
      return piece == piece.toLowerCase();
    }
  }

  // NEW: Get possible moves using detailed legal moves from API
  List<String> getPossibleMovesFromDetailed(String from) {
    if (legalMovesDetailed.isEmpty) {
      // Fallback to old method if detailed moves not available
      return getPossibleMoves(from);
    }

    return legalMovesDetailed
        .where((move) => move['from'] == from)
        .map((move) => move['to'] as String)
        .toList();
  }

  // NEW: Get dangerous moves using detailed legal moves from API
  List<String> getDangerousMovesFromDetailed(String from) {
    if (legalMovesDetailed.isEmpty) {
      // Fallback to old method if detailed moves not available
      return getDangerousMoves(from, getPossibleMoves(from));
    }

    final dangerous = <String>[];

    for (final move in legalMovesDetailed) {
      if (move['from'] == from) {
        final to = move['to'] as String;
        final isCapture = move['is_capture'] == true;
        final isProtected = move['is_protected'] == true;
        final isVulnerable = move['is_vulnerable'] == true;

        // Mark as dangerous if:
        // 1. It's a capture of a protected piece
        // 2. It's a move to a vulnerable square
        if ((isCapture && isProtected) || isVulnerable) {
          dangerous.add(to);
        }
      }
    }

    return dangerous;
  }

  List<String> getPossibleMoves(String from) {
    final piece = board[from];
    if (piece == null) return [];

    print('DEBUG getPossibleMoves: from=$from, piece=$piece');
    print('DEBUG legalMoves: ${legalMoves.join(", ")}');

    final List<String> moves = [];
    final pieceType = piece.toUpperCase();
    
    // Strip check and checkmate notation from all legal moves first
    final cleanMoves = legalMoves.map((m) => m.replaceAll('+', '').replaceAll('#', '')).toList();
    
    // Helper function to check if a square is reachable
    bool canReach(String fromSq, String toSq, String type) {
      final fromFile = fromSq.codeUnitAt(0) - 97;
      final fromRank = int.parse(fromSq[1]);
      final toFile = toSq.codeUnitAt(0) - 97;
      final toRank = int.parse(toSq[1]);
      final fileDiff = (toFile - fromFile).abs();
      final rankDiff = (toRank - fromRank).abs();
      
      switch (type) {
        case 'N':
          return (fileDiff == 2 && rankDiff == 1) || (fileDiff == 1 && rankDiff == 2);
        case 'B':
          return fileDiff == rankDiff && fileDiff > 0;
        case 'R':
          return (fileDiff == 0 && rankDiff > 0) || (rankDiff == 0 && fileDiff > 0);
        case 'Q':
          return ((fileDiff == 0 && rankDiff > 0) || (rankDiff == 0 && fileDiff > 0)) ||
                 (fileDiff == rankDiff && fileDiff > 0);
        case 'K':
          return fileDiff <= 1 && rankDiff <= 1 && (fileDiff > 0 || rankDiff > 0);
        default:
          return true;
      }
    }
    
    for (final move in cleanMoves) {
      // Coordinate notation (e.g., g1f3, e7e8q)
      if (RegExp(r'^[a-h][1-8][a-h][1-8][qrbnQBRN]?$').hasMatch(move)) {
        if (move.substring(0, 2) == from) {
          moves.add(move.substring(2, 4));
          print('DEBUG: Matched coordinate move: $move -> ${move.substring(2, 4)}');
        }
        continue;
      }
      
      // Simple piece moves (e.g., Nf3, Bf4)
      if (RegExp(r'^[NBRQK][a-h][1-8]$').hasMatch(move)) {
        final p = move[0];
        final toSq = move.substring(1, 3);
        if (pieceType == p && canReach(from, toSq, p)) {
          moves.add(toSq);
        }
        continue;
      }
      
      // Simple piece captures (e.g., Nxf3, Bxh6)
      if (RegExp(r'^[NBRQK]x[a-h][1-8]$').hasMatch(move)) {
        final p = move[0];
        final toSq = move.substring(2, 4);
        if (pieceType == p && canReach(from, toSq, p)) {
          moves.add(toSq);
        }
        continue;
      }
      
      // Disambiguation (e.g., Nbd2, R1e2)
      if (RegExp(r'^[NBRQK][a-h1-8][a-h][1-8]$').hasMatch(move)) {
        final p = move[0];
        final dis = move[1];
        final toSq = move.substring(2, 4);
        if (pieceType == p && (from[0] == dis || from[1] == dis)) {
          moves.add(toSq);
        }
        continue;
      }
      
      // Disambiguation with capture (e.g., Ngxf3, N1xf3)
      if (RegExp(r'^[NBRQK][a-h1-8]x[a-h][1-8]$').hasMatch(move)) {
        final p = move[0];
        final dis = move[1];
        final toSq = move.substring(move.length - 2);
        if (pieceType == p && (from[0] == dis || from[1] == dis)) {
          moves.add(toSq);
        }
        continue;
      }
      
      // Pawn push (e.g., e4, e8=Q)
      if (RegExp(r'^[a-h][1-8](=[QRNB])?$').hasMatch(move)) {
        if (pieceType == 'P' && from[0] == move[0]) {
          moves.add(move.substring(0, 2));
        }
        continue;
      }
      
      // Pawn capture (e.g., exd5, exd8=Q)
      if (RegExp(r'^[a-h]x[a-h][1-8](=[QRNB])?$').hasMatch(move)) {
        if (pieceType == 'P' && from[0] == move[0]) {
          moves.add(move.substring(2, 4));
        }
        continue;
      }
      
      // Castling (O-O, O-O-O)
      if (RegExp(r'^O-O(-O)?$').hasMatch(move)) {
        if ((from == 'e1' && playerColor == 'white' && piece == 'K') ||
            (from == 'e8' && playerColor == 'black' && piece == 'k')) {
          moves.add(move == 'O-O'
              ? (playerColor == 'white' ? 'g1' : 'g8')
              : (playerColor == 'white' ? 'c1' : 'c8'));
        }
        continue;
      }
    }
    
    print('DEBUG getPossibleMoves result: ${moves.join(", ")}');
    return moves;
  }
  
  List<String> getDangerousMoves(String from, List<String> moves) {
    final piece = board[from];
    if (piece == null) return [];
    
    final dangerous = <String>[];
    final enemyColor = playerColor == 'white' ? 'black' : 'white';
    
    for (final toSquare in moves) {
      final attackers = <String>[];
      
      // Find all enemy pieces that can attack this square
      for (final entry in board.entries) {
        final sq = entry.key;
        final p = entry.value;
        
        // Skip if not enemy piece
        if (enemyColor == 'white') {
          if (p != p.toUpperCase()) continue;
        } else {
          if (p != p.toLowerCase()) continue;
        }
        
        // Check if this enemy piece can attack toSquare
        if (canPieceAttack(sq, p, toSquare)) {
          attackers.add(sq);
        }
      }
      
      // If only the enemy king can attack, check if it would be safe for the king
      if (attackers.length == 1) {
        final attackerSquare = attackers[0];
        final attackerPiece = board[attackerSquare];
        if (attackerPiece != null && attackerPiece.toLowerCase() == 'k') {
          // Check if the moving piece itself protects toSquare
          if (canPieceAttack(toSquare, piece, attackerSquare)) {
            // The piece protects itself, king cannot capture
            continue; // Don't mark as dangerous
          }
          
          // Check if our OTHER pieces can attack where the king would be
          bool kingWouldBeInDanger = false;
          for (final entry in board.entries) {
            final sq = entry.key;
            final p = entry.value;
            
            // Skip the piece we're moving and skip if not our piece
            if (sq == from) continue;
            if (playerColor == 'white') {
              if (p != p.toUpperCase()) continue;
            } else {
              if (p != p.toLowerCase()) continue;
            }
            
            // Check if this piece can attack where the king would be
            if (canPieceAttack(sq, p, toSquare)) {
              kingWouldBeInDanger = true;
              break;
            }
          }
          
          // If king would be in danger, this move is actually safe
          if (kingWouldBeInDanger) {
            continue; // Don't mark as dangerous
          }
        }
      }
      
      // Mark as dangerous if there are attackers
      if (attackers.isNotEmpty) {
        dangerous.add(toSquare);
      }
    }
    
    return dangerous;
  }
  
  bool canPieceAttack(String from, String piece, String to) {
    final fromFile = from.codeUnitAt(0) - 97;
    final fromRank = int.parse(from[1]);
    final toFile = to.codeUnitAt(0) - 97;
    final toRank = int.parse(to[1]);
    final fileDiff = (toFile - fromFile).abs();
    final rankDiff = (toRank - fromRank).abs();
    
    final type = piece.toUpperCase();
    
    switch (type) {
      case 'P':
        // Pawn attacks diagonally one square
        final isWhite = piece == piece.toUpperCase();
        final direction = isWhite ? 1 : -1;
        return fileDiff == 1 && (toRank - fromRank) == direction;
        
      case 'N':
        return (fileDiff == 2 && rankDiff == 1) || (fileDiff == 1 && rankDiff == 2);
        
      case 'B':
        if (fileDiff != rankDiff || fileDiff == 0) return false;
        return !isPathBlocked(from, to);
        
      case 'R':
        if (!((fileDiff == 0 && rankDiff > 0) || (rankDiff == 0 && fileDiff > 0))) return false;
        return !isPathBlocked(from, to);
        
      case 'Q':
        final isDiagonal = fileDiff == rankDiff && fileDiff > 0;
        final isStraight = (fileDiff == 0 && rankDiff > 0) || (rankDiff == 0 && fileDiff > 0);
        if (!isDiagonal && !isStraight) return false;
        return !isPathBlocked(from, to);
        
      case 'K':
        return fileDiff <= 1 && rankDiff <= 1 && (fileDiff > 0 || rankDiff > 0);
        
      default:
        return false;
    }
  }
  
  bool isPathBlocked(String from, String to) {
    final fromFile = from.codeUnitAt(0) - 97;
    final fromRank = int.parse(from[1]);
    final toFile = to.codeUnitAt(0) - 97;
    final toRank = int.parse(to[1]);
    
    final fileStep = (toFile - fromFile).sign;
    final rankStep = (toRank - fromRank).sign;
    
    int currentFile = fromFile + fileStep;
    int currentRank = fromRank + rankStep;
    
    while (currentFile != toFile || currentRank != toRank) {
      final square = String.fromCharCode(97 + currentFile) + currentRank.toString();
      if (board[square] != null) return true;
      
      currentFile += fileStep;
      currentRank += rankStep;
    }
    
    return false;
  }

  String getPieceSymbol(String piece) {
    // White pieces use OUTLINED symbols, black pieces use FILLED symbols
    // This provides natural visual differentiation
    const symbols = {
      'P': '♙', 'p': '♟',  // Pawn: outlined vs filled
      'R': '♖', 'r': '♜',  // Rook: outlined vs filled
      'N': '♘', 'n': '♞',  // Knight: outlined vs filled
      'B': '♗', 'b': '♝',  // Bishop: outlined vs filled
      'Q': '♕', 'q': '♛',  // Queen: outlined vs filled
      'K': '♔', 'k': '♚',  // King: outlined vs filled
    };
    return symbols[piece] ?? piece;
  }

  String? findKing(String color) {
    final kingSymbol = color == 'white' ? 'K' : 'k';
    for (final entry in board.entries) {
      if (entry.value == kingSymbol) {
        return entry.key;
      }
    }
    return null;
  }

  Future<String?> showPromotionDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Promote Pawn'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPromotionButton('q', '♕'),
              _buildPromotionButton('r', '♖'),
              _buildPromotionButton('b', '♗'),
              _buildPromotionButton('n', '♘'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromotionButton(String piece, String symbol) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(piece),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }

  void showHintDialog() {
    // Debug: print what we have
    print('DEBUG: suggestedMove = $suggestedMove');
    print('DEBUG: moveExplanation = $moveExplanation');
    print('DEBUG: legalMovesDetailed count: ${legalMovesDetailed.length}');

    if (suggestedMove == null || suggestedMove!.isEmpty) {
      showMessage('No hint available', MessageType.info);
      return;
    }

    // NEW: Find the coordinate move from legalMovesDetailed by matching the SAN notation
    String? findCoordinateMove() {
      // First check if it's castling
      if (suggestedMove == 'O-O' || suggestedMove == 'O-O-O') {
        return suggestedMove;
      }

      // Try to find in detailed legal moves
      if (legalMovesDetailed.isNotEmpty) {
        // The suggestedMove is in SAN format (e.g., "Nf3", "e4")
        // We need to find the matching detailed move
        for (final moveDetail in legalMovesDetailed) {
          final moveStr = moveDetail['move'] as String?;
          if (moveStr != null && moveStr == suggestedMove) {
            final from = moveDetail['from'] as String?;
            final to = moveDetail['to'] as String?;
            if (from != null && to != null) {
              print('DEBUG: Found match in detailed moves: $from$to');
              return from + to;
            }
          }
        }
      }

      // Fallback: try to extract from explanation
      if (moveExplanation != null && moveExplanation!.isNotEmpty) {
        // Check for castling in explanation
        if (moveExplanation!.toLowerCase().contains('castle')) {
          if (moveExplanation!.toLowerCase().contains('kingside')) {
            return 'O-O';
          } else if (moveExplanation!.toLowerCase().contains('queenside')) {
            return 'O-O-O';
          }
        }

        // Try to find pattern like "d1 to d2" or "c1 to h6"
        final match = RegExp(r'([a-h][1-8])\s+to\s+([a-h][1-8])').firstMatch(moveExplanation!);
        if (match != null) {
          final from = match.group(1)!;
          final to = match.group(2)!;
          return from + to;
        }
      }

      return null;
    }

    final coordinateMove = findCoordinateMove();
    print('DEBUG: coordinateMove = $coordinateMove');
    
    // Show dialog with the move and explanation
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('💡 Hint'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested Move:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    suggestedMove!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Explanation:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moveExplanation ?? 'No explanation available.',
                        style: TextStyle(
                          fontSize: 14,
                          color: moveExplanation != null ? Colors.black87 : Colors.grey,
                          fontStyle: moveExplanation != null ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      // NEW: Show book move indicator
                      if (moveExplanation != null &&
                          (moveExplanation!.contains('book move') ||
                           moveExplanation!.contains('opening theory') ||
                           moveExplanation!.contains('GM games')))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.book, size: 16, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Opening Book Move',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('Cancel'),
            ),
            if (coordinateMove != null)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  
                  // Handle castling notation
                  if (coordinateMove == 'O-O' || coordinateMove == 'O-O-O') {
                    // Send castling move directly to backend
                    try {
                      final response = await http.post(
                        Uri.parse('$apiUrl/make_move'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'session_id': sessionId,
                          'move': coordinateMove,
                        }),
                      );

                      if (response.statusCode == 200) {
                        final data = jsonDecode(response.body);
                        await updateGameState();
                        
                        if (data['game_over'] == true) {
                          setState(() {
                            gameStatus = 'finished';
                          });
                          showGameResult(data);
                        } else if (currentPlayer != playerColor && gameStatus == 'active') {
                          await Future.delayed(const Duration(milliseconds: 500));
                          await makeAIMove();
                        }
                      } else {
                        final data = jsonDecode(response.body);
                        showError(data['error'] ?? 'Invalid move');
                      }
                    } catch (e) {
                      showError('Error making move: $e');
                    }
                  } else if (coordinateMove.length >= 4) {
                    // Regular move
                    final from = coordinateMove.substring(0, 2);
                    final to = coordinateMove.substring(2, 4);
                    makeMove(from, to);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Make Move'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        );
      },
    );
  }

  void showGameResult(Map<String, dynamic> data) {
    String message = '';
    bool isCheckmate = false;
    
    if (data['checkmate'] == true) {
      final winner = currentPlayer == 'white' ? 'Black' : 'White';
      message = 'Checkmate! $winner wins! 🎉';
      isCheckmate = true;
    } else if (data['stalemate'] == true) {
      message = 'Stalemate! Draw!';
    } else if (data['draw'] == true) {
      message = 'Draw!';
    }
    
    showMessage(message, MessageType.success);
    
    // Show celebration dialog for checkmate
    if (isCheckmate) {
      Future.delayed(const Duration(milliseconds: 500), () {
        showCheckmateDialog(currentPlayer == 'white' ? 'Black' : 'White');
      });
    }
  }
  
  void showCheckmateDialog(String winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎊 '),
              Text(
                'Checkmate!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[700],
                ),
              ),
              const Text(' 🎊'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🏆',
                style: TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 16),
              Text(
                '$winner Wins!',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🎉 🎊 ✨ 🎆 🎇',
                style: TextStyle(fontSize: 32),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                startNewGame();
              },
              icon: const Icon(Icons.replay),
              label: const Text('New Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
  
  void copyMovesToClipboard() {
    if (moveHistory.isEmpty) {
      showMessage('No moves to copy', MessageType.info);
      return;
    }
    
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Chess Game Analysis');
    buffer.writeln('===================');
    buffer.writeln('Player Color: $playerColor');
    buffer.writeln('AI Difficulty: $aiDifficulty');
    buffer.writeln('Game Status: $gameStatus');
    buffer.writeln('');
    buffer.writeln('Moves:');
    
    for (int i = 0; i < moveHistory.length; i += 2) {
      final moveNum = (i / 2 + 1).toInt();
      final whiteMove = moveHistory[i];
      final blackMove = i + 1 < moveHistory.length ? moveHistory[i + 1] : '';
      
      if (moveDetails != null && i < moveDetails!.length) {
        final whiteDetail = moveDetails![i];
        final whitePiece = whiteDetail['piece'] ?? '';
        final whiteFrom = whiteDetail['from'] ?? '';
        final whiteTo = whiteDetail['to'] ?? '';
        final whiteCapture = whiteDetail['capture'] ?? false;
        final whiteArrow = whiteCapture ? '×' : '→';
        
        if (i + 1 < moveDetails!.length && blackMove.isNotEmpty) {
          final blackDetail = moveDetails![i + 1];
          final blackPiece = blackDetail['piece'] ?? '';
          final blackFrom = blackDetail['from'] ?? '';
          final blackTo = blackDetail['to'] ?? '';
          final blackCapture = blackDetail['capture'] ?? false;
          final blackArrow = blackCapture ? '×' : '→';
          
          buffer.writeln('$moveNum. $whitePiece $whiteFrom $whiteArrow $whiteTo | $blackPiece $blackFrom $blackArrow $blackTo');
        } else {
          buffer.writeln('$moveNum. $whitePiece $whiteFrom $whiteArrow $whiteTo');
        }
      } else {
        buffer.writeln('$moveNum. $whiteMove ${blackMove.isNotEmpty ? '| $blackMove' : ''}');
      }
    }
    
    final movesText = buffer.toString();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Moves'),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Long press the text below to select and copy:',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      movesText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                // Create mailto URL
                final subject = Uri.encodeComponent('Chess Game Analysis');
                final body = Uri.encodeComponent(movesText);
                final mailtoUrl = 'mailto:?subject=$subject&body=$body';
                
                showMessage('Opening email app...', MessageType.info);
                // In a real app, you would use url_launcher package here
                // For now, show instructions
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Email Instructions'),
                    content: SelectableText(
                      'To email this game:\n\n'
                      '1. Long press and copy all the text from the previous dialog\n'
                      '2. Open your email app\n'
                      '3. Paste the copied text\n'
                      '4. Send to your desired recipient\n\n'
                      'Or use the text below:\n\n$movesText',
                      style: const TextStyle(fontSize: 12),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.email),
              label: const Text('Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void resign() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resign Game'),
          content: const Text('Are you sure you want to resign?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  gameStatus = 'finished';
                });
                showMessage('You resigned the game', MessageType.info);
              },
              child: const Text('Resign'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: 24,
          style: backgroundColor != null
              ? IconButton.styleFrom(backgroundColor: backgroundColor)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: onPressed == null ? Colors.grey : Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('♔ Chess Game ♛'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Game Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          isAIThinking
                              ? 'AI is thinking...'
                              : '${currentPlayer.toUpperCase()} to move',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (inCheck && gameStatus == 'active')
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              border: Border.all(color: Colors.red, width: 4),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '⚠️ CHECK! ⚠️',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (gameStatus == 'finished')
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Game Over',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Captured Pieces - Black
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Captured by White:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          capturedPieces['white']!.isEmpty
                              ? '-'
                              : capturedPieces['white']!
                                  .map((p) => getPieceSymbol(p))
                                  .join(' '),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Controls - Icon buttons with labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIconButton(
                      icon: Icons.refresh,
                      label: 'New',
                      onPressed: isLoading ? null : startNewGame,
                    ),
                    const SizedBox(width: 16),
                    _buildIconButton(
                      icon: Icons.lightbulb,
                      label: 'Hint',
                      onPressed: (gameStatus == 'active' && !isAIThinking) ? showHintDialog : null,
                    ),
                    const SizedBox(width: 16),
                    _buildIconButton(
                      icon: Icons.flag,
                      label: 'Resign',
                      onPressed: gameStatus == 'active' ? resign : null,
                      backgroundColor: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: playerColor,
                      items: const [
                        DropdownMenuItem(
                          value: 'white',
                          child: Text('Play as White'),
                        ),
                        DropdownMenuItem(
                          value: 'black',
                          child: Text('Play as Black'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null && !isLoading) {
                          setState(() {
                            playerColor = value;
                          });
                        }
                      },
                    ),
                    DropdownButton<int>(
                      value: aiDifficulty,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Easy (1)')),
                        DropdownMenuItem(value: 2, child: Text('Medium (2)')),
                        DropdownMenuItem(value: 3, child: Text('Hard (3)')),
                        DropdownMenuItem(value: 4, child: Text('Expert (4)')),
                        DropdownMenuItem(value: 5, child: Text('Master (5)')),
                      ],
                      onChanged: (value) {
                        if (value != null && !isLoading) {
                          setState(() {
                            aiDifficulty = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chess Board
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  _buildChessBoard(),
                  
                const SizedBox(height: 16),

                // Captured Pieces - White
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Captured by Black:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          capturedPieces['black']!.isEmpty
                              ? '-'
                              : capturedPieces['black']!
                                  .map((p) => getPieceSymbol(p))
                                  .join(' '),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Move History
                Card(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Move History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: moveHistory.isNotEmpty ? copyMovesToClipboard : null,
                              icon: const Icon(Icons.copy),
                              tooltip: 'Copy Moves',
                              iconSize: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            itemCount: (moveHistory.length / 2).ceil(),
                            itemBuilder: (context, index) {
                              final blackMove = index * 2 + 1 < moveHistory.length
                                  ? moveHistory[index * 2 + 1]
                                  : '';
                              
                              String formatMove(int idx) {
                                if (moveDetails != null && idx < moveDetails!.length) {
                                  final detail = moveDetails![idx];
                                  final piece = detail['piece'] ?? '';
                                  final from = detail['from'] ?? '';
                                  final to = detail['to'] ?? '';
                                  final capture = detail['capture'] ?? false;
                                  final arrow = capture ? '×' : '→';
                                  return '$piece $from $arrow $to';
                                }
                                return moveHistory[idx];
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '${index + 1}. ${formatMove(index * 2)}${blackMove.isNotEmpty ? ' ${formatMove(index * 2 + 1)}' : ''}',
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChessBoard() {
    // Calculate square size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // padding
    final squareSize = ((availableWidth - 30 - 6) / 8).clamp(35.0, 50.0); // rank numbers + border
    final rankWidth = 25.0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rank numbers (8-1)
        Column(
          children: List.generate(8, (index) {
            final rank = 8 - index;
            return Container(
              width: rankWidth,
              height: squareSize,
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            );
          }),
        ),
        // Chess board
        Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown, width: 3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: List.generate(8, (rank) {
                  return Row(
                    children: List.generate(8, (file) {
                      final fileChar = String.fromCharCode(97 + file);
                      final square = '$fileChar${8 - rank}';
                      final piece = board[square];
                      final isLight = (rank + file) % 2 == 1;
                      final isSelected = selectedSquare == square;
                      final isHighlighted = highlightedSquare == square;
                      final isPossible = possibleMoves.contains(square);
                      final isLastMoveSquare = lastMove != null &&
                          (lastMove!['from'] == square || lastMove!['to'] == square);
                      final isKingInCheck = inCheck &&
                          piece != null &&
                          piece.toLowerCase() == 'k' &&
                          findKing(currentPlayer) == square;
                      // NEW: Check if piece is under attack
                      final isUnderAttack = piecesUnderAttack.contains(square);

                      return GestureDetector(
                        onTap: () => onSquareTap(square),
                        onLongPress: () => onSquareLongPress(square),
                        child: SizedBox(
                          width: squareSize,
                          height: squareSize,
                          child: Stack(
                            children: [
                              // Background color
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.yellow
                                        : isHighlighted
                                            ? Colors.yellow[200]
                                            : isKingInCheck
                                                ? Colors.red[300]
                                                : isLastMoveSquare
                                                    ? Colors.yellow[100]
                                                    : isLight
                                                        ? const Color(0xFFF0D9B5)
                                                        : const Color(0xFFB58863),
                                  ),
                                ),
                              ),
                              // Piece or move indicator
                              Center(
                                child: piece != null
                                    ? Text(
                                        getPieceSymbol(piece),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          color: Colors.black,  // Single color for all pieces
                                          shadows: [
                                            // Add subtle shadow for depth
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 2,
                                              color: Color.fromARGB(128, 0, 0, 0),
                                            ),
                                          ],
                                        ),
                                      )
                                    : isPossible && board[square] == null
                                        ? Container(
                                            width: squareSize * 0.24,
                                            height: squareSize * 0.24,
                                            decoration: BoxDecoration(
                                              color: Colors.green.withAlpha(179),
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : null,
                              ),
                              // Show danger indicator (red slash) on dangerous moves
                              if (isPossible && dangerousMoves.contains(square))
                                CustomPaint(
                                  size: Size(squareSize, squareSize),
                                  painter: CaptureIndicatorPainter(),
                                ),
                              // Green border for possible moves (overlay - doesn't affect layout)
                              if (isPossible)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.green,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              // Orange border for pieces under attack (overlay - doesn't affect layout)
                              if (isUnderAttack)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.orange,
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            // File letters (a-h)
            Row(
              children: List.generate(8, (index) {
                final file = String.fromCharCode(97 + index);
                return Container(
                  width: squareSize,
                  height: 25,
                  alignment: Alignment.center,
                  child: Text(
                    file,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}

enum MessageType {
  info,
  success,
  error,
}

// Custom painter to draw a red diagonal slash over capturable pieces
class CaptureIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Draw diagonal line from top-left to bottom-right
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.85),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
