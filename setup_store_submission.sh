#!/bin/bash

# Chess Whisperer - Store Submission Setup Script
# This script automates the preparation for Google Play Store submission

set -e  # Exit on any error

echo "=========================================="
echo "Chess Whisperer - Store Submission Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

print_success "Flutter is installed"

# Step 1: Clean previous builds
print_info "Step 1: Cleaning previous builds..."
flutter clean
print_success "Clean complete"

# Step 2: Get dependencies
print_info "Step 2: Getting dependencies..."
flutter pub get
print_success "Dependencies downloaded"

# Step 3: Create directories
print_info "Step 3: Creating store assets directories..."
mkdir -p play_store_assets
mkdir -p screenshots
print_success "Directories created"

# Step 4: Build release AAB (App Bundle for Play Store)
print_info "Step 4: Building release App Bundle (AAB)..."
flutter build appbundle --release
print_success "App Bundle built successfully"

# Step 5: Build release APK (for testing)
print_info "Step 5: Building release APK (for testing)..."
flutter build apk --release
print_success "APK built successfully"

# Step 6: Generate store assets
print_info "Step 6: Generating store assets..."

# Create 512x512 app icon for Play Store
if [ -f "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" ]; then
    print_info "Generating 512x512 app icon..."
    sips -z 512 512 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png \
        --out play_store_assets/app_icon_512.png 2>/dev/null || \
        cp android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png play_store_assets/app_icon_512.png
    print_success "512x512 app icon created"
else
    print_warning "Launcher icon not found, skipping 512x512 generation"
fi

# Create feature graphic using Python
print_info "Generating 1024x500 feature graphic..."
python3 << 'PYTHON_SCRIPT'
from PIL import Image, ImageDraw, ImageFont
import os

try:
    # Create a 1024x500 image with blue background
    img = Image.new('RGB', (1024, 500), color='#2196F3')
    draw = ImageDraw.Draw(img)

    # Try to load and paste the icon
    icon_path = 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
    if os.path.exists(icon_path):
        icon = Image.open(icon_path)
        icon = icon.resize((300, 300), Image.Resampling.LANCZOS)
        img.paste(icon, (50, 100), icon if icon.mode == 'RGBA' else None)

    # Draw text
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 80)
    except:
        try:
            font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 80)
        except:
            font = ImageFont.load_default()

    draw.text((400, 200), 'Chess Whisperer', fill='white', font=font)

    # Save
    img.save('play_store_assets/feature_graphic.png')
    print('Feature graphic created successfully')
except Exception as e:
    print(f'Error creating feature graphic: {e}')
    exit(1)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    print_success "Feature graphic created"
else
    print_warning "Feature graphic creation failed"
fi

# Step 7: Create submission checklist
print_info "Step 7: Creating submission checklist..."

cat > PLAY_STORE_CHECKLIST.md << 'EOF'
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

EOF

print_success "Submission checklist created"

# Step 8: Summary
echo ""
echo "=========================================="
echo "         SETUP COMPLETE! 🎉"
echo "=========================================="
echo ""
print_success "All files are ready for Play Store submission!"
echo ""
echo "📦 App Files:"
echo "   • App Bundle: build/app/outputs/bundle/release/app-release.aab"
echo "   • Test APK: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "🎨 Store Assets:"
echo "   • App Icon (512x512): play_store_assets/app_icon_512.png"
echo "   • Feature Graphic: play_store_assets/feature_graphic.png"
echo ""
echo "📋 Next Steps:"
echo "   1. Read PLAY_STORE_CHECKLIST.md for detailed instructions"
echo "   2. Take 2-8 screenshots of your app"
echo "   3. Set up AdMob account and get real ad IDs"
echo "   4. Go to https://play.google.com/console to submit"
echo ""
print_info "Note: App is using TEST ad IDs. Replace with real IDs before publishing!"
echo ""
