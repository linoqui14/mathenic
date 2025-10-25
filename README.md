# MATHENIC

**Scan. Solve. Learn.** - AI-powered math problem solver that uses your camera to instantly recognize and solve mathematical problems.

## Features

- 📸 Real-time camera scanning for math problems
- 🤖 AI-powered problem recognition and solving
- 💡 Step-by-step solutions with markdown rendering
- 🌓 Dark/Light theme support
- 📚 Problem history tracking with SQLite
- ✨ Beautiful animations with Lottie
- 📱 Cross-platform support (Android & iOS)

## Requirements

### System Requirements
- **Operating System**: macOS, Windows, or Linux
- **Flutter SDK**: 3.6.1 or higher
- **Dart SDK**: 3.6.1 or higher
- **IDE**: Android Studio, VS Code, or IntelliJ IDEA

### For Android Development
- Android Studio Ladybug or later
- Android SDK (API level 21 or higher)
- Java Development Kit (JDK) 11 or higher

### For iOS Development (macOS only)
- Xcode 15 or later
- CocoaPods
- iOS 12.0 or higher

## Installation

### Step 1: Install Flutter

#### macOS
```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

#### Windows
1. Download Flutter SDK from [flutter.dev](https://flutter.dev/docs/get-started/install/windows)
2. Extract the zip file to desired location (e.g., `C:\src\flutter`)
3. Add Flutter to PATH:
    - Search for "Environment Variables" in Windows
    - Add `C:\src\flutter\bin` to Path
4. Run `flutter doctor` in Command Prompt

#### Linux
```bash
# Download and extract Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Install dependencies
sudo apt-get install curl git unzip xz-utils zip libglu1-mesa

# Verify installation
flutter doctor
```

### Step 2: Install Flutter Dependencies

Run `flutter doctor` and follow the instructions to install any missing dependencies:

```bash
flutter doctor -v
```

Common fixes:
- **Android toolchain**: Install Android Studio and Android SDK
- **Xcode** (macOS only): Install from App Store
- **cmdline-tools**: Accept Android licenses with `flutter doctor --android-licenses`

### Step 3: Clone the Repository

```bash
git clone https://github.com/yourusername/mathenic.git
cd mathenic
```

### Step 4: Install Project Dependencies

```bash
flutter pub get
```

### Step 5: Configure Environment Variables

Create a `.env` file in the project root:

```env
GEMINI_API_KEY=your_gemini_api_key_here
```

**Get your API key:**
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create or select a project
3. Generate API key
4. Copy the key to `.env` file

### Step 6: Add Lottie Animations

The project uses Lottie animations. Ensure these files exist in `assets/lottie/`:
- `logo.json` - App logo animation
- `scan.json` - Scanning animation overlay

You can download free Lottie animations from [LottieFiles](https://lottiefiles.com/).

### Step 7: Run the Application

#### For Android
```bash
# List available devices
flutter devices

# Run on connected device or emulator
flutter run
```

#### For iOS (macOS only)
```bash
# Install CocoaPods dependencies
cd ios
pod install
cd ..

# Run on connected device or simulator
flutter run
```

## Project Structure

```
mathenic/
├── lib/
│   ├── main.dart              # App entry point & theme management
│   ├── models/                # Data models
│   │   └── math_result.dart   # Math result data structure
│   ├── pages/                 # UI screens
│   │   ├── camera.dart        # Camera scanning page
│   │   ├── result_page.dart   # Result display page
│   │   └── history_page.dart  # History page
│   ├── providers/             # State management
│   │   └── result_provider.dart
│   ├── services/              # Business logic
│   │   ├── gemini_service.dart    # AI integration
│   │   └── database_helper.dart   # SQLite operations
│   └── theme/                 # App theming
│       └── app_theme.dart     # Light/Dark themes
├── assets/
│   └── lottie/               # Lottie animations
│       ├── logo.json
│       └── scan.json
├── android/                  # Android-specific code
├── ios/                      # iOS-specific code
├── .env                      # Environment variables (create this)
├── pubspec.yaml              # Dependencies
└── README.md
```

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Camera & ML
  camera: ^0.10.5+5
  image_picker: ^1.0.4
  google_mlkit_text_recognition: ^0.11.0
  permission_handler: ^11.0.1
  image: ^4.1.3

  # AI Integration
  google_generative_ai: ^0.2.0
  http: ^1.1.0

  # UI Components
  flutter_markdown: ^0.7.4
  markdown: ^7.2.2
  lottie: ^3.1.0

  # State Management
  provider: ^6.1.1

  # Storage
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  path: ^1.8.3
  shared_preferences: ^2.2.2

  # Environment
  flutter_dotenv: ^5.1.0
```

## Platform Configuration

### Android Permissions

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

    <application
        android:label="Mathenic"
        android:icon="@mipmap/ic_launcher">
        <!-- Your app configuration -->
    </application>
</manifest>
```

### iOS Permissions

Edit `ios/Runner/Info.plist`:

```xml
<dict>
    <key>NSCameraUsageDescription</key>
    <string>Camera access is required to scan math problems</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Photo library access is required to select images</string>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>Photo library access is required to save images</string>
    <!-- Other configurations -->
</dict>
```

## Building for Production

### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Google Play)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS
```bash
flutter build ios --release
```
Then open `ios/Runner.xcworkspace` in Xcode and archive.

## Key Features Implementation

### 1. Camera Scanning
- Real-time text recognition using Google ML Kit
- Manual and automatic capture modes
- Stability detection for accurate captures
- Center frame focusing

### 2. AI Processing
- Google Gemini AI integration
- Lazy loading for question, answer, and solution
- Markdown rendering for formatted solutions
- Subject classification

### 3. UI/UX
- Light and dark theme support
- Smooth animations with Lottie
- Loading states with shimmer effects
- Responsive bottom sheet for results

### 4. Data Persistence
- SQLite database for history
- Shared Preferences for settings
- Image caching with path_provider

## Troubleshooting

### Common Issues

#### 1. Flutter doctor shows issues
```bash
flutter doctor -v
```
Follow the recommended fixes for each issue.

#### 2. Gradle build fails (Android)
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

#### 3. CocoaPods issues (iOS)
```bash
cd ios
pod deintegrate
pod install
cd ..
```

#### 4. Camera permission denied
- Check permissions in manifest files
- Verify device settings allow camera access
- Request permissions at runtime

#### 5. API key not working
- Verify `.env` file exists in project root
- Check API key is valid in Google AI Studio
- Ensure `.env` is listed in `pubspec.yaml` assets

#### 6. Lottie animations not showing
```bash
# Verify assets are declared in pubspec.yaml
flutter clean
flutter pub get
```

### Debug Commands

```bash
# Check Flutter version
flutter --version

# List connected devices
flutter devices

# Run with verbose logging
flutter run -v

# Clear build cache
flutter clean
```

## Development Tips

### Hot Reload
Use hot reload during development:
- Press `r` in terminal
- Click hot reload in IDE

### Debugging
- Use `debugPrint()` for logging
- Enable debug mode: `flutter run --debug`
- Use DevTools: `flutter pub global run devtools`

### Code Quality
```bash
# Format code
flutter format .

# Analyze code
flutter analyze
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Coding Standards
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Write unit tests for new features

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- **Email**: support@mathenic.app
- **Issues**: [GitHub Issues](https://github.com/yourusername/mathenic/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/mathenic/discussions)

## Acknowledgments

- [Google ML Kit](https://developers.google.com/ml-kit) for text recognition
- [Google Gemini AI](https://ai.google.dev/) for problem solving
- [LottieFiles](https://lottiefiles.com/) for animations
- [Flutter Team](https://flutter.dev/) for the amazing framework
- [pub.dev](https://pub.dev/) community for excellent packages

## Roadmap

- [ ] Handwriting recognition
- [ ] Multiple language support
- [ ] Graphing calculator
- [ ] Formula sheet library
- [ ] Study mode with practice problems
- [ ] Cloud sync for history
- [ ] Social features (share solutions)

---

**Made with ❤️ by the MATHENIC Team**

*Scan. Solve. Learn.*