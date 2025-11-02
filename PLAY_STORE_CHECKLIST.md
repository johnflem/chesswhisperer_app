# Google Play Store Submission Checklist

## ✅ Pre-Submission Checklist

### 1. App Files Ready
- [ ] App Bundle: `build/app/outputs/bundle/release/app-release.aab` (22.5 MB)
- [ ] 512x512 Icon: `play_store_assets/app_icon_512.png`
- [ ] Feature Graphic: `play_store_assets/feature_graphic.png`
- [ ] Screenshots: Take 2-8 phone screenshots

### 2. AdMob Setup (Required for Monetization)
- [ ] Create AdMob account at https://admob.google.com
- [ ] Create app in AdMob
- [ ] Get App ID and replace in `android/app/src/main/AndroidManifest.xml:40`
- [ ] Get Interstitial Ad Unit ID and replace in `lib/services/ad_service.dart:14`

### 3. In-App Purchase Setup (Required for "Remove Ads")
- [ ] Create in-app product in Play Console
- [ ] Product ID: `remove_ads`
- [ ] Set price (recommended: $2.99)
- [ ] Activate product

### 4. Store Listing Information

**App Name:** Chess Whisperer

**Short Description (80 chars max):**
Play chess against AI, watch master games, and improve your skills

**Full Description:**
Chess Whisperer is your ultimate chess companion for Android. Whether you're a beginner or an experienced player, our app offers:

🎮 PLAY AGAINST AI
- Multiple difficulty levels from beginner to expert
- Visual move indicators showing AI's last move
- Move history tracking
- Board notation (a-h, 1-8) for learning

👁️ WATCH MASTER GAMES
- Browse and study games from chess masters
- Step-by-step playback controls
- Variable playback speed (0.5s to 5s between moves)
- Collapsible controls for optimal viewing

✨ FEATURES
- Clean, intuitive interface
- Portrait and landscape support
- Real-time game state updates
- Comprehensive move notation

Perfect for learning chess strategies, practicing against AI, or studying how the masters play!

**Category:** Games → Board

**Content Rating:** Everyone

**Tags:** chess, board game, AI, strategy, master games

**Contact Email:** [YOUR EMAIL]

**Privacy Policy URL:** [YOUR URL OR "Not applicable"]

### 5. App Content Declarations
- [ ] Privacy Policy (if collecting data)
- [ ] Ads declaration: Yes (AdMob)
- [ ] In-app purchases: Yes (Remove Ads)
- [ ] Target audience: Everyone
- [ ] Content ratings questionnaire

### 6. Testing
- [ ] Test on physical Android device
- [ ] Test all game modes work
- [ ] Test ads show (with test IDs)
- [ ] Test in-app purchase flow (sandbox)
- [ ] Test on different screen sizes

## 📋 Submission Steps

1. **Go to Google Play Console:** https://play.google.com/console

2. **Create App:**
   - Click "Create app"
   - App name: Chess Whisperer
   - Default language: English (United States)
   - App or game: Game
   - Free or paid: Free

3. **Complete All Sections:**
   - Store presence → Main store listing
   - Store presence → Store settings
   - Policy → App content
   - Policy → Privacy policy
   - Grow → Store listing experiments (optional)

4. **Upload App Bundle:**
   - Production → Releases
   - Create new release
   - Upload `app-release.aab`
   - Add release notes

5. **Set Pricing & Distribution:**
   - Countries: Select all or specific
   - Pricing: Free
   - Content guidelines: Accept

6. **Submit for Review:**
   - Review all sections (must show green checkmarks)
   - Click "Send for review"
   - Wait 1-3 days for approval

## ⚙️ Post-Submission

### After Approval:
- [ ] Update AdMob IDs from test to production
- [ ] Verify in-app purchase works
- [ ] Monitor crash reports
- [ ] Respond to user reviews

### Version Updates:
- [ ] Increment version in `pubspec.yaml`
- [ ] Build new AAB: `flutter build appbundle --release`
- [ ] Upload to Play Console
- [ ] Add release notes

## 📱 Important Info

**Package Name:** com.fleminganalytic.chess_whisperer
**Version:** 1.0.0+1
**Backend API:** https://fleminganalytic.com/chess

## 🔗 Useful Links

- Google Play Console: https://play.google.com/console
- AdMob: https://admob.google.com
- Flutter Docs: https://docs.flutter.dev
- Play Store Policies: https://play.google.com/about/developer-content-policy/

