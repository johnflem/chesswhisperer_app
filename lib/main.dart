import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chess_game_screen.dart';
import 'services/chess_api_service.dart';
import 'services/ad_service.dart';
import 'services/iap_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService().initialize();
  await IAPService().initialize();
  runApp(const ChessWhispererApp());
}

class ChessWhispererApp extends StatelessWidget {
  const ChessWhispererApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ChessApiService>(
          create: (_) => ChessApiService(
            baseUrl: 'https://fleminganalytic.com/chess',
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Chess Whisperer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3498db),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3498db),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const ChessGameScreen(),
      ),
    );
  }
}
