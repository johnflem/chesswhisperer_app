import 'package:flutter/material.dart' hide Color;
import 'package:flutter/material.dart' as material;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:provider/provider.dart';
import '../services/chess_api_service.dart';
import '../services/ad_service.dart';
import '../models/master_game.dart';
import 'dart:async';

class WatchGamesTab extends StatefulWidget {
  const WatchGamesTab({super.key});

  @override
  State<WatchGamesTab> createState() => _WatchGamesTabState();
}

class _WatchGamesTabState extends State<WatchGamesTab> {
  late ChessBoardController _boardController;
  List<MasterGame> _allGames = [];
  List<MasterGame> _filteredGames = [];
  List<String> _players = [];
  MasterGame? _currentGame;
  int _currentMoveIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  Timer? _playTimer;
  int _speed = 5; // seconds between moves
  String? _selectedPlayer;
  String? _highlightedSquare;
  material.Color? _highlightColor;
  bool _controlsExpanded = true; // Controls accordion state

  // ELO filter ranges
  String _selectedEloRange = 'all';
  final List<Map<String, dynamic>> _eloRanges = [
    {'label': 'All ELO Ranges', 'value': 'all'},
    {'label': '2700-2800', 'value': '2700-2800'},
    {'label': '2800-2850', 'value': '2800-2850'},
    {'label': '2850-2900', 'value': '2850-2900'},
    {'label': '2900-2950', 'value': '2900-2950'},
    {'label': '2950-3000', 'value': '2950-3000'},
    {'label': '3000+', 'value': '3000-5000'},
  ];

  @override
  void initState() {
    super.initState();
    _boardController = ChessBoardController();
    _loadGames();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _boardController.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    try {
      final apiService = context.read<ChessApiService>();

      // Load first 300 games only (6 API calls instead of 22)
      // These are the highest ELO games which are most interesting
      final List<MasterGame> allGames = [];
      const int pageSize = 50;
      const int maxGames = 300; // Limit to 300 games for faster loading

      for (int offset = 0; offset < maxGames; offset += pageSize) {
        final gamesResponse = await apiService.searchGames(
          limit: pageSize,
          offset: offset,
        );
        final games = (gamesResponse['games'] as List)
            .map((g) => MasterGame.fromJson(g as Map<String, dynamic>))
            .toList();
        allGames.addAll(games);

        // Update UI after first batch so user sees progress
        if (offset == 0) {
          setState(() {
            _allGames = allGames;
            _filteredGames = allGames;
          });
        }
      }

      // Load unique players
      final playersResponse = await apiService.getUniquePlayers();
      final players =
          (playersResponse['players'] as List).cast<String>().toList();

      setState(() {
        _allGames = allGames;
        _filteredGames = allGames;
        _players = players;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load games: $e');
    }
  }

  void _filterGames() {
    setState(() {
      _filteredGames = _allGames.where((game) {
        // Filter by player
        bool playerMatch = _selectedPlayer == null ||
            game.white == _selectedPlayer ||
            game.black == _selectedPlayer;

        // Filter by ELO
        bool eloMatch = true;
        if (_selectedEloRange != 'all') {
          final parts = _selectedEloRange.split('-');
          final min = int.parse(parts[0]);
          final max = int.parse(parts[1]);
          eloMatch = game.averageElo >= min && game.averageElo < max;
        }

        return playerMatch && eloMatch;
      }).toList();

      // Sort by average ELO (highest first)
      _filteredGames.sort((a, b) => b.averageElo.compareTo(a.averageElo));
    });
  }

  void _selectGame(MasterGame game) async {
    // Show ad before loading game
    await AdService().showInterstitialAd();

    _stopPlaying();

    // If game doesn't have moves, fetch full game details
    if (game.moves.isEmpty) {
      try {
        final apiService = Provider.of<ChessApiService>(context, listen: false);
        final gameResponse = await apiService.getGame(game.gameId);
        final fullGame = MasterGame.fromJson(gameResponse);

        setState(() {
          _currentGame = fullGame;
          _currentMoveIndex = 0;
        });

        _boardController.loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
        if (mounted) Navigator.pop(context);
        return;
      } catch (e) {
        _showError('Failed to load game details: $e');
        return;
      }
    }

    setState(() {
      _currentGame = game;
      _currentMoveIndex = 0;
    });

    // Show starting position
    _boardController.loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    if (mounted) Navigator.pop(context); // Close the game selection dialog
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _stopPlaying();
    } else {
      _startPlaying();
    }
  }

  void _startPlaying() {
    if (_currentGame == null) return;

    setState(() => _isPlaying = true);

    // Make the first move immediately (after 1 second) so user sees action
    Future.delayed(const Duration(seconds: 1), () {
      if (_isPlaying && _currentMoveIndex < _currentGame!.moveCount) {
        _makeNextMove();
      }
    });

    // Then continue with regular timer for subsequent moves
    _playTimer = Timer.periodic(Duration(seconds: _speed), (timer) {
      if (_currentMoveIndex >= _currentGame!.moveCount) {
        _stopPlaying();
        return;
      }

      _makeNextMove();
    });
  }

  void _stopPlaying() {
    _playTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  Future<void> _makeNextMove() async {
    if (_currentGame == null ||
        _currentMoveIndex >= _currentGame!.moveCount) {
      return;
    }

    final move = _currentGame!.moves[_currentMoveIndex];

    // Phase 1: Highlight FROM square (2 seconds)
    setState(() {
      _highlightedSquare = move.fromSquare;
      _highlightColor = material.Colors.blue;
    });

    await Future.delayed(const Duration(milliseconds: 2000));

    // Phase 2: Delay (0.5 seconds)
    setState(() {
      _highlightedSquare = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Phase 3: Move the piece
    _boardController.loadFen(move.fenAfter);

    // Phase 4: Highlight TO square (1.5 seconds)
    setState(() {
      _highlightedSquare = move.toSquare;
      _highlightColor = material.Colors.red;
      _currentMoveIndex++;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      _highlightedSquare = null;
    });

    // Check if game is finished
    if (_currentMoveIndex >= _currentGame!.moveCount) {
      _stopPlaying();
      _showGameResult();
    }
  }

  void _showGameResult() {
    if (_currentGame == null) return;

    String winnerText;

    if (_currentGame!.result == '1-0') {
      winnerText = '${_currentGame!.white} wins!';
    } else if (_currentGame!.result == '0-1') {
      winnerText = '${_currentGame!.black} wins!';
    } else {
      winnerText = 'Draw';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              winnerText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Result: ${_currentGame!.result}'),
            Text('White: ${_currentGame!.white} (${_currentGame!.whiteElo})'),
            Text('Black: ${_currentGame!.black} (${_currentGame!.blackElo})'),
            Text('Moves: ${_currentGame!.moveCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: const Text('Replay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _previousMove() {
    if (_currentGame == null || _currentMoveIndex == 0) return;

    setState(() {
      _currentMoveIndex--;
    });

    if (_currentMoveIndex == 0) {
      _boardController.loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    } else {
      _boardController.loadFen(_currentGame!.moves[_currentMoveIndex - 1].fenAfter);
    }
  }

  void _nextMove() {
    if (_currentGame == null ||
        _currentMoveIndex >= _currentGame!.moveCount) {
      return;
    }

    _makeNextMove();
  }

  void _resetGame() {
    _stopPlaying();

    setState(() {
      _currentMoveIndex = 0;
    });

    _boardController.loadFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
  }

  void _showGameSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select a Game',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Row(
                          children: [
                            Text(
                              '${_filteredGames.length} games',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_isLoading) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Loading...',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Filters
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPlayer,
                            decoration: const InputDecoration(
                              labelText: 'Player',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Players'),
                              ),
                              ..._players.map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setModalState(() => _selectedPlayer = value);
                              setState(() => _selectedPlayer = value);
                              _filterGames();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedEloRange,
                            decoration: const InputDecoration(
                              labelText: 'ELO Range',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _eloRanges
                                .map(
                                  (range) => DropdownMenuItem<String>(
                                    value: range['value'] as String,
                                    child: Text(range['label'] as String),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => _selectedEloRange = value);
                                setState(() => _selectedEloRange = value);
                                _filterGames();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Games List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _filteredGames.length,
                      itemBuilder: (context, index) {
                        final game = _filteredGames[index];
                        return ListTile(
                          title: Text(game.gameTitle),
                          subtitle: Text(
                            '${game.event} • Avg ELO: ${game.averageElo} • ${game.moveCount} moves',
                          ),
                          trailing: Chip(
                            label: Text(game.result),
                            backgroundColor:
                                Theme.of(context).colorScheme.secondaryContainer,
                          ),
                          onTap: () => _selectGame(game),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildHighlightOverlay(String square, material.Color color) {
    // Convert chess square notation (e.g., "e2") to board position
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0-7 (a-h)
    final rank = int.parse(square[1]) - 1; // 0-7 (1-8)

    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final squareSize = constraints.maxWidth / 8;
            final left = file * squareSize;
            final top = (7 - rank) * squareSize; // Flip rank for display

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: squareSize,
                  height: squareSize,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.5),
                      border: Border.all(
                        color: color,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _downloadMoves() {
    if (_currentGame == null) {
      _showError('No game selected');
      return;
    }

    // Create PGN format
    final pgn = StringBuffer();
    pgn.writeln('[Event "${_currentGame!.event}"]');
    pgn.writeln('[White "${_currentGame!.white}"]');
    pgn.writeln('[Black "${_currentGame!.black}"]');
    pgn.writeln('[Result "${_currentGame!.result}"]');
    pgn.writeln('[Date "${_currentGame!.date}"]');
    pgn.writeln('[WhiteElo "${_currentGame!.whiteElo}"]');
    pgn.writeln('[BlackElo "${_currentGame!.blackElo}"]');
    pgn.writeln('');

    // Add moves
    for (int i = 0; i < _currentGame!.moves.length; i++) {
      if (i % 2 == 0) {
        pgn.write('${(i ~/ 2) + 1}. ');
      }
      pgn.write('${_currentGame!.moves[i].san} ');
      if (i % 2 == 1) {
        pgn.write('\n');
      }
    }
    pgn.writeln('\n${_currentGame!.result}');

    // Show dialog with PGN content
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Moves (PGN Format)'),
        content: SingleChildScrollView(
          child: SelectableText(
            pgn.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isLandscape ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collapsible header section
          if (_controlsExpanded) ...[
            // Game Selection Button - compact in landscape
            Card(
              child: ListTile(
                dense: isLandscape,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8 : 16,
                  vertical: isLandscape ? 0 : 8,
                ),
                title: Text(
                  _currentGame?.gameTitle ?? 'No game selected',
                  style: TextStyle(fontSize: isLandscape ? 14 : 16),
                ),
                subtitle: _currentGame != null
                    ? Text(
                        'Move $_currentMoveIndex/${_currentGame!.moveCount} • ELO ${_currentGame!.averageElo}',
                        style: TextStyle(fontSize: isLandscape ? 11 : 12),
                      )
                    : Text(
                        'Tap to select a master game',
                        style: TextStyle(fontSize: isLandscape ? 12 : 14),
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentGame != null)
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: 'Download moves (PGN)',
                        onPressed: _downloadMoves,
                        iconSize: isLandscape ? 20 : 24,
                      ),
                    Icon(Icons.arrow_forward_ios, size: isLandscape ? 16 : 20),
                  ],
                ),
                onTap: _showGameSelector,
              ),
            ),

            SizedBox(height: isLandscape ? 8 : 16),
          ],

          // Playback Controls - compact in landscape, always visible with collapse button
          if (_currentGame != null) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(isLandscape ? 8 : 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Collapse/Expand button
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _controlsExpanded = !_controlsExpanded;
                            });
                          },
                          icon: Icon(_controlsExpanded ? Icons.expand_less : Icons.expand_more),
                          tooltip: _controlsExpanded ? 'Hide header' : 'Show header',
                          iconSize: isLandscape ? 20 : 24,
                        ),
                        // Playback controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filled(
                              onPressed: _togglePlayPause,
                              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                              iconSize: isLandscape ? 20 : 24,
                            ),
                            IconButton.outlined(
                              onPressed: _previousMove,
                              icon: const Icon(Icons.skip_previous),
                              iconSize: isLandscape ? 20 : 24,
                            ),
                            IconButton.outlined(
                              onPressed: _nextMove,
                              icon: const Icon(Icons.skip_next),
                              iconSize: isLandscape ? 20 : 24,
                            ),
                            IconButton.outlined(
                              onPressed: _resetGame,
                              icon: const Icon(Icons.replay),
                              iconSize: isLandscape ? 20 : 24,
                            ),
                          ],
                        ),
                        if (isLandscape)
                          DropdownButton<int>(
                            value: _speed,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5s')),
                              DropdownMenuItem(value: 10, child: Text('10s')),
                              DropdownMenuItem(value: 15, child: Text('15s')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _speed = value;
                                });
                                if (_isPlaying) {
                                  _stopPlaying();
                                  _startPlaying();
                                }
                              }
                            },
                          ),
                      ],
                    ),
                    if (!isLandscape) ...[
                      const SizedBox(height: 16),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 5, label: Text('5s')),
                          ButtonSegment(value: 10, label: Text('10s')),
                          ButtonSegment(value: 15, label: Text('15s')),
                        ],
                        selected: {_speed},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(() {
                            _speed = newSelection.first;
                          });
                          if (_isPlaying) {
                            _stopPlaying();
                            _startPlaying();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 16),
          ],

          // Chess Board with highlighting
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final boardIsLandscape = screenWidth > screenHeight;

                // In landscape: use smaller dimension minus padding for square board
                // In portrait: use full width minus more padding for right margin
                final maxSize = boardIsLandscape
                    ? (screenHeight - 150).clamp(200.0, 600.0)  // Leave 150px for header/controls
                    : screenWidth - 48; // Increased from 32 to 48 for more right margin

                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 2.0,
                  boundaryMargin: const EdgeInsets.all(20),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: maxSize,
                      maxHeight: maxSize,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: [
                          ChessBoard(
                            controller: _boardController,
                            boardColor: BoardColor.brown,
                            enableUserMoves: false,
                          ),
                          if (_highlightedSquare != null)
                            _buildHighlightOverlay(_highlightedSquare!, _highlightColor!),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
