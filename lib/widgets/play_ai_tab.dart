import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/ad_service.dart';

class PlayAiTab extends StatefulWidget {
  const PlayAiTab({super.key});

  @override
  State<PlayAiTab> createState() => _PlayAiTabState();
}

class _PlayAiTabState extends State<PlayAiTab> {
  String? sessionId;
  Map<String, String> board = {};
  List<String> legalMoves = [];
  List<Map<String, dynamic>> legalMovesDetailed = [];
  String currentPlayer = 'white';
  String gameStatus = 'active';
  bool inCheck = false;
  String playerColor = 'white';
  int aiDifficulty = 1;
  String? selectedSquare;
  String? highlightedSquare;
  List<String> possibleMoves = [];
  List<String> dangerousMoves = [];
  List<String> piecesUnderAttack = [];
  bool isLoading = false;
  bool isAIThinking = false;
  Map<String, dynamic>? lastMove;
  String? suggestedMove;
  String? moveExplanation;
  List<String> moveHistory = [];
  List<Map<String, dynamic>>? moveDetails;
  String? _highlightedSquare;
  Color? _highlightColor;
  String? _lastAIMoveNotation;

  final String apiUrl = 'https://fleminganalytic.com/chess';

  @override
  void initState() {
    super.initState();
    startNewGame();
  }

  Future<void> startNewGame() async {
    // Show ad before starting new game
    await AdService().showInterstitialAd();

    setState(() {
      isLoading = true;
      gameStatus = 'active';
      selectedSquare = null;
      highlightedSquare = null;
      possibleMoves = [];
      moveHistory = [];
      moveDetails = null;
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

        if (playerColor == 'black' && currentPlayer == 'white') {
          await Future.delayed(const Duration(milliseconds: 500));
          await makeAIMove();
        }
      }
    } catch (e) {
      showError('Failed to start game: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
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
          lastMove = data['last_move'];
          suggestedMove = data['suggested_next_move'];
          moveExplanation = data['move_explanation'];
          piecesUnderAttack = data['pieces_under_attack'] != null
              ? List<String>.from(data['pieces_under_attack'])
              : [];

          // Update move history from game state
          if (data['move_history'] != null) {
            moveHistory = List<String>.from(data['move_history']);
          }
          if (data['move_details'] != null) {
            moveDetails = List<Map<String, dynamic>>.from(
              (data['move_details'] as List).map((e) => Map<String, dynamic>.from(e))
            );
          }
        });

        final movesResponse = await http.get(
          Uri.parse('$apiUrl/legal_moves/$sessionId'),
        );

        if (movesResponse.statusCode == 200) {
          final movesData = jsonDecode(movesResponse.body);
          setState(() {
            legalMoves = List<String>.from(movesData['legal_moves'] ?? []);
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

  Future<void> makeMove(String from, String to) async {
    if (sessionId == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/make_move'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'move': from + to,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract AI move squares for flash animation
        String? aiFromSquare = data['ai_from_square'] as String?;
        String? aiToSquare = data['ai_to_square'] as String?;

        // Step 1: First show YOUR move on the board (optimistic update)
        setState(() {
          // Move your piece on the UI immediately
          final piece = board[from];
          if (piece != null) {
            board.remove(from);
            board[to] = piece;

            // Handle castling - move the rook too
            if ((piece == 'K' || piece == 'k') && (from == 'e1' || from == 'e8')) {
              // Check if this is a castling move (king moves 2 squares)
              final fromFile = from.codeUnitAt(0);
              final toFile = to.codeUnitAt(0);
              if ((toFile - fromFile).abs() == 2) {
                // Kingside castling (king to g-file)
                if (toFile > fromFile) {
                  final rank = from[1];
                  final rookFrom = 'h$rank';
                  final rookTo = 'f$rank';
                  final rook = board[rookFrom];
                  if (rook != null) {
                    board.remove(rookFrom);
                    board[rookTo] = rook;
                  }
                }
                // Queenside castling (king to c-file)
                else {
                  final rank = from[1];
                  final rookFrom = 'a$rank';
                  final rookTo = 'd$rank';
                  final rook = board[rookFrom];
                  if (rook != null) {
                    board.remove(rookFrom);
                    board[rookTo] = rook;
                  }
                }
              }
            }
          }
        });

        // Small delay so user sees their move
        await Future.delayed(const Duration(milliseconds: 300));

        // Step 2: Flash the AI's move squares (if available)
        if (aiFromSquare != null && aiToSquare != null) {
          await _flashMoveSquares(aiFromSquare, aiToSquare);
        }

        // Step 3: Now update to the real game state (which includes AI's move)
        await updateGameState();

        // Check if the last move in history was by the AI (to update notation)
        if (moveHistory.length >= 2) {
          final lastMove = moveHistory[moveHistory.length - 1];
          setState(() {
            _lastAIMoveNotation = lastMove;
          });
        }

        if (data['game_over'] == true) {
          setState(() => gameStatus = 'finished');
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

    setState(() => isAIThinking = true);

    try {
      await Future.delayed(const Duration(seconds: 1));

      final response = await http.post(
        Uri.parse('$apiUrl/get_ai_move'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': sessionId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMove = data['ai_move'] as String?;

        // Try to get from/to squares from the API response (new backend)
        String? fromSquare = data['from_square'] as String?;
        String? toSquare = data['to_square'] as String?;

        print('========================================');
        print('AI MOVE RESPONSE:');
        print('ai_move: $aiMove');
        print('from_square: $fromSquare');
        print('to_square: $toSquare');
        print('Has from_square: ${fromSquare != null}');
        print('Has to_square: ${toSquare != null}');
        print('========================================');

        await updateGameState();

        setState(() => isAIThinking = false);

        // Flash the AI's last move
        if (mounted && fromSquare != null && toSquare != null) {
          print('ATTEMPTING TO FLASH: from=$fromSquare to=$toSquare');

          setState(() {
            _lastAIMoveNotation = aiMove;
          });

          await _flashMoveSquares(fromSquare, toSquare);

          print('FLASH COMPLETED');
        } else {
          print('CANNOT FLASH: mounted=$mounted, fromSquare=$fromSquare, toSquare=$toSquare');
          // Still set the notation even if we can't flash
          if (aiMove != null) {
            setState(() {
              _lastAIMoveNotation = aiMove;
            });
          }
        }

        if (data['game_over'] == true) {
          setState(() => gameStatus = 'finished');
          showGameResult(data);
        }
      }
    } catch (e) {
      showError('Error getting AI move: $e');
      setState(() => isAIThinking = false);
    }
  }

  void onSquareTap(String square) {
    if (gameStatus != 'active' || currentPlayer != playerColor) return;

    final piece = board[square];

    if (selectedSquare == null) {
      if (piece != null && isPieceOwnedByPlayer(piece)) {
        setState(() {
          selectedSquare = square;
          possibleMoves = getPossibleMovesFromDetailed(square);
          dangerousMoves = getDangerousMovesFromDetailed(square);
          _lastAIMoveNotation = null; // Clear AI move notation when player selects piece
        });
      }
    } else {
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

  bool isPieceOwnedByPlayer(String piece) {
    if (playerColor == 'white') {
      return piece == piece.toUpperCase();
    } else {
      return piece == piece.toLowerCase();
    }
  }

  List<String> getPossibleMovesFromDetailed(String from) {
    if (legalMovesDetailed.isEmpty) return [];

    return legalMovesDetailed
        .where((move) => move['from'] == from)
        .map((move) => move['to'] as String)
        .toList();
  }

  List<String> getDangerousMovesFromDetailed(String from) {
    if (legalMovesDetailed.isEmpty) return [];

    final dangerous = <String>[];

    for (final move in legalMovesDetailed) {
      if (move['from'] == from) {
        final to = move['to'] as String;
        final isCapture = move['is_capture'] == true;
        final isProtected = move['is_protected'] == true;
        final isVulnerable = move['is_vulnerable'] == true;

        if ((isCapture && isProtected) || isVulnerable) {
          dangerous.add(to);
        }
      }
    }

    return dangerous;
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showGameResult(Map<String, dynamic> data) {
    String message = '';
    if (data['checkmate'] == true) {
      final winner = currentPlayer == 'white' ? 'Black' : 'White';
      message = 'Checkmate! $winner wins! 🎉';
    } else if (data['stalemate'] == true) {
      message = 'Stalemate! Draw!';
    } else if (data['draw'] == true) {
      message = 'Draw!';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              startNewGame();
            },
            child: const Text('New Game'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String getPieceSymbol(String piece) {
    const symbols = {
      'P': '♙', 'p': '♟',
      'R': '♖', 'r': '♜',
      'N': '♘', 'n': '♞',
      'B': '♗', 'b': '♝',
      'Q': '♕', 'q': '♛',
      'K': '♔', 'k': '♚',
    };
    return symbols[piece] ?? piece;
  }

  Future<void> _flashMoveSquares(String from, String to) async {
    // Phase 1: Highlight FROM square (bright yellow, 1500ms)
    if (mounted) {
      setState(() {
        _highlightedSquare = from;
        _highlightColor = Colors.yellow;
      });
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    // Phase 2: Highlight TO square (bright green, 1500ms)
    if (mounted) {
      setState(() {
        _highlightedSquare = to;
        _highlightColor = Colors.green;
      });
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    // Phase 3: Clear highlight
    if (mounted) {
      setState(() {
        _highlightedSquare = null;
      });
    }
  }

  void copyMovesToClipboard() {
    if (moveHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No moves to copy')),
      );
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
          content: SingleChildScrollView(
            child: SelectableText(movesText),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: movesText));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Moves copied to clipboard!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    isAIThinking
                        ? 'AI is thinking...'
                        : _lastAIMoveNotation != null
                            ? 'Last move: $_lastAIMoveNotation'
                            : '${currentPlayer.toUpperCase()} to move',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (inCheck && gameStatus == 'active')
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        border: Border.all(color: Colors.red, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠️ CHECK! ⚠️',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<String>(
                value: playerColor,
                items: const [
                  DropdownMenuItem(value: 'white', child: Text('Play White')),
                  DropdownMenuItem(value: 'black', child: Text('Play Black')),
                ],
                onChanged: (v) {
                  if (v != null && !isLoading) {
                    setState(() => playerColor = v);
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
                onChanged: (v) {
                  if (v != null && !isLoading) {
                    setState(() => aiDifficulty = v);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: isLoading ? null : startNewGame,
            icon: const Icon(Icons.refresh),
            label: const Text('New Game'),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const CircularProgressIndicator()
          else
            _buildChessBoard(),
          const SizedBox(height: 16),
          if (!isLoading) _buildMoveHistory(),
        ],
      ),
    );
  }

  Widget _buildMoveHistory() {
    return Card(
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
              child: moveHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No moves yet',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
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
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${index + 1}. ${formatMove(index * 2)}${blackMove.isNotEmpty ? ' ${formatMove(index * 2 + 1)}' : ''}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChessBoard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 48; // Extra padding for right margin
    final squareSize = (availableWidth / 8).clamp(30.0, 50.0);
    final labelSize = 20.0; // Fixed size for labels

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main board with left rank labels and top
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left rank labels (8-1)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(8, (rank) {
                return SizedBox(
                  width: labelSize,
                  height: squareSize,
                  child: Center(
                    child: Text(
                      '${8 - rank}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Chess board
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown, width: 3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(8, (rank) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
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
              final isUnderAttack = piecesUnderAttack.contains(square);

              return GestureDetector(
                onTap: isAIThinking ? null : () => onSquareTap(square),
                child: SizedBox(
                  width: squareSize,
                  height: squareSize,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: isSelected
                              ? Colors.yellow
                              : isHighlighted
                                  ? Colors.yellow[200]
                                  : isLastMoveSquare
                                      ? Colors.yellow[100]
                                      : isLight
                                          ? const Color(0xFFF0D9B5)
                                          : const Color(0xFFB58863),
                        ),
                      ),
                      Center(
                        child: piece != null
                            ? Text(
                                getPieceSymbol(piece),
                                style: TextStyle(
                                  fontSize: squareSize * 0.7,
                                  color: Colors.black,
                                ),
                              )
                            : isPossible && board[square] == null
                                ? Container(
                                    width: squareSize * 0.24,
                                    height: squareSize * 0.24,
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                      ),
                      if (isPossible && dangerousMoves.contains(square))
                        CustomPaint(
                          size: Size(squareSize, squareSize),
                          painter: CaptureIndicatorPainter(),
                        ),
                      if (isPossible)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 3),
                            ),
                          ),
                        ),
                      if (isUnderAttack)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange, width: 4),
                            ),
                          ),
                        ),
                      if (_highlightedSquare == square && _highlightColor != null)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _highlightColor!.withValues(alpha: 0.5),
                              border: Border.all(
                                color: _highlightColor!,
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
          ],
        ),
        // Bottom file labels (a-h)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: labelSize), // Space for left rank labels
            ...List.generate(8, (file) {
              final fileChar = String.fromCharCode(97 + file);
              return SizedBox(
                width: squareSize,
                height: labelSize,
                child: Center(
                  child: Text(
                    fileChar,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class CaptureIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.85),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
