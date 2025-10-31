# Chess Whisperer - Flutter App

A modern Flutter chess application with AI play and master games replay functionality.

## Features

### Play vs AI Mode
- Choose your color (White or Black)
- 5 difficulty levels (Easy to Master)
- Interactive chess board with move validation
- Hint system
- Move history tracking

### Watch Master Games Mode
- Browse 1000+ master games
- Filter by player name
- Filter by average ELO rating
- Auto-replay with configurable speed (5s, 10s, 15s)
- Move-by-move highlighting:
  - Blue flash on FROM square (2 seconds)
  - 0.5 second delay
  - Piece moves
  - Red flash on TO square (1.5 seconds)
- Manual navigation (Previous/Next/Reset)

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Android Studio / Xcode (for mobile development)
- Chrome (for web development)

### Installation

1. **Navigate to the Flutter app directory:**
   ```bash
   cd /var/www/fleminganalytic/flutter_chess_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on your preferred platform:**

   **Web:**
   ```bash
   flutter run -d chrome
   ```

   **Android:**
   ```bash
   flutter run -d android
   ```

   **iOS:**
   ```bash
   flutter run -d ios
   ```

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── models/
│   └── master_game.dart          # Master game data models
├── screens/
│   └── chess_game_screen.dart    # Main screen with tab navigation
├── services/
│   └── chess_api_service.dart    # Backend API integration
└── widgets/
    ├── play_ai_tab.dart          # Play vs AI interface
    └── watch_games_tab.dart      # Watch master games interface
```

## Backend API

The app connects to your existing FastAPI backend at:
`https://fleminganalytic.com/chess`

### Endpoints Used:

**Play vs AI:**
- `POST /new_game` - Create new game session
- `POST /move/{session_id}` - Make a player move
- `GET /hint/{session_id}` - Get move hint

**Master Games:**
- `GET /games/count` - Get total games count
- `GET /games/search` - Search games with filters
- `GET /games/{game_id}` - Get specific game details
- `GET /games/players` - Get unique player list

## Key Technologies

- **Flutter 3.0+** - UI framework
- **Provider** - State management
- **flutter_chess_board** - Chess board widget with piece rendering
- **chess** - Chess logic and move validation
- **http** - API communication

## Design Highlights

### Modern Material Design 3
- Adaptive color schemes (light/dark mode)
- Filled and outlined buttons
- Cards with elevation
- Segmented buttons for speed control
- Modal bottom sheets for game selection

### Smooth Animations
- 4-second move sequence with visual feedback
- Blue → Red highlighting pattern
- Configurable playback speed
- Responsive UI transitions

### User Experience
- Tab navigation for easy mode switching
- Dropdown filters for game selection
- Progress indicators during AI thinking
- Error handling with snackbar notifications
- Disable interaction during replay mode

## Customization

### Changing API URL
Edit `lib/main.dart`:
```dart
ChessApiService(
  baseUrl: 'YOUR_API_URL_HERE',
),
```

### Modifying Animation Timing
Edit `lib/widgets/watch_games_tab.dart`:
```dart
// FROM square flash duration
await Future.delayed(const Duration(milliseconds: 2000));

// Delay between FROM and move
await Future.delayed(const Duration(milliseconds: 500));

// TO square flash duration
await Future.delayed(const Duration(milliseconds: 1500));
```

### Adjusting Speed Options
Edit `lib/widgets/watch_games_tab.dart`:
```dart
SegmentedButton<int>(
  segments: const [
    ButtonSegment(value: 5, label: Text('5s')),
    ButtonSegment(value: 10, label: Text('10s')),
    ButtonSegment(value: 15, label: Text('15s')),
  ],
  // ...
)
```

## Building for Production

### Android APK
```bash
flutter build apk --release
```

### iOS IPA
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Troubleshooting

### Dependencies not installing
```bash
flutter clean
flutter pub get
```

### Board not rendering
Make sure you've run `flutter pub get` to install `flutter_chess_board` package.

### API connection failing
Check that your backend is running and accessible. Update the `baseUrl` in `main.dart` if needed.

## Future Enhancements

- [ ] Persistent game state (save/resume)
- [ ] Offline mode with local Stockfish engine
- [ ] Game analysis with best move suggestions
- [ ] User accounts and game history
- [ ] Multiplayer over network
- [ ] Puzzle mode
- [ ] Opening explorer

## License

This project is part of the Fleming Analytic suite.
