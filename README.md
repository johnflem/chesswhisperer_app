# Chess Whisperer

A Flutter chess application with AI gameplay, master game analysis, and monetization features ready for Play Store.

## Features

### 🎮 Play vs AI
- Multiple difficulty levels (Beginner to Expert)
- Choose your color (White or Black)
- AI move flash animation (yellow FROM → green TO)
- Real-time move validation
- Move history with detailed notation
- Board notation labels (a-h, 1-8)
- Board locked during AI thinking

### 👁️ Watch Master Games
- Browse 1000+ games from chess masters
- Filter by player name and ELO rating
- Variable playback speed (0.5s to 5s between moves)
- Instant first move (1 second after selection)
- Collapsible interface for optimal viewing
- Move-by-move navigation
- Pinch-to-zoom board support

### 💰 Monetization (Play Store Ready)
- **AdMob Integration**: Interstitial ads on game start
- **In-App Purchase**: Remove ads with one-time payment
- Test ads included (replace with production IDs)
- Cross-platform IAP support (Android & iOS)
- Settings screen for ad removal purchase

### 🎨 Polish & UX
- Splash screen on app launch
- Responsive layout (portrait/landscape)
- Settings screen with gear icon
- Visual feedback during AI thinking
- Instant game responsiveness

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

### Automated Setup (Recommended)
```bash
./setup_store_submission.sh
```

This script automatically:
- Cleans and rebuilds the project
- Generates release App Bundle (AAB) for Play Store
- Generates release APK for testing
- Creates store assets (512x512 icon, feature graphic)
- Generates complete submission checklist

### Manual Build

**Android App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

**Android APK (for testing):**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## Play Store Submission

### Quick Start
1. Run `./setup_store_submission.sh`
2. Read `PLAY_STORE_CHECKLIST.md` for complete guide
3. Set up AdMob account and get production ad IDs
4. Upload AAB to Google Play Console

### Required Before Publishing
- Replace test ad IDs with production IDs:
  - `android/app/src/main/AndroidManifest.xml:40` (App ID)
  - `lib/services/ad_service.dart:14` (Interstitial Ad Unit ID)
- Set up in-app product `remove_ads` in Play Console
- Take 2-8 screenshots for store listing

### Generated Assets
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab` (28 MB)
- **512x512 Icon**: `play_store_assets/app_icon_512.png`
- **Feature Graphic**: `play_store_assets/feature_graphic.png`
- **Checklist**: `PLAY_STORE_CHECKLIST.md`

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
