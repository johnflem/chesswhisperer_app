import 'dart:convert';
import 'package:http/http.dart' as http;

class ChessApiService {
  final String baseUrl;

  ChessApiService({required this.baseUrl});

  // Play vs AI endpoints
  Future<Map<String, dynamic>> createNewGame({
    required String playerColor,
    required int aiDifficulty,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/new_game'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'player_color': playerColor,
        'ai_difficulty': aiDifficulty,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create new game');
    }
  }

  Future<Map<String, dynamic>> makeMove({
    required String sessionId,
    required String fromSquare,
    required String toSquare,
    String? promotion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/move/$sessionId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': fromSquare,
        'to': toSquare,
        if (promotion != null) 'promotion': promotion,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to make move');
    }
  }

  Future<Map<String, dynamic>> getHint(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hint/$sessionId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get hint');
    }
  }

  // Master Games endpoints
  Future<Map<String, dynamic>> getGamesCount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/count'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get games count');
    }
  }

  Future<Map<String, dynamic>> searchGames({
    String? player,
    int? minMoves,
    String? result,
    int? limit,
    int? offset,
  }) async {
    var uri = Uri.parse('$baseUrl/games/search');
    final queryParams = <String, String>{};

    if (player != null) queryParams['player'] = player;
    if (minMoves != null) queryParams['min_moves'] = minMoves.toString();
    if (result != null) queryParams['result'] = result;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search games');
    }
  }

  Future<Map<String, dynamic>> getGame(int gameId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/$gameId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get game');
    }
  }

  Future<Map<String, dynamic>> getUniquePlayers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/players'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get players');
    }
  }
}
