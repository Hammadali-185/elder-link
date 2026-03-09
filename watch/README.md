# ElderLink - Smartwatch UI Prototype

A Flutter-based smartwatch UI prototype designed for elderly users in a home care system. The interface is optimized for a 1.3-inch touchscreen with large, high-contrast buttons and simple navigation.

## Features

### 🏠 Home Screen
- Four large, high-contrast buttons:
  - Medicine Reminder
  - Panic Button
  - Health Monitoring
  - Audio (Quran)
- Settings button at the bottom

### 💊 Medicine Reminder Screen
- Displays medicine name, dosage, and time
- Three action buttons: TAKEN, SNOOZE, MISSED
- Vibration feedback on button press
- Automatic navigation back after selection

### 🚨 Panic Button Screen
- Large red panic button in center
- Requires 2-second hold to prevent accidental activation
- Visual countdown during hold
- Confirmation message after alert is sent
- Vibration feedback

### ❤️ Health Monitoring Screen
- Heart Rate monitoring
- Blood Pressure monitoring
- START READING button to begin measurement
- Abnormal reading warnings
- Visual feedback during reading process

### 🎵 Audio Screen
- Simple audio player interface
- Play/Pause/Stop controls
- Previous/Next track navigation
- Current track name display
- Optimized for Quran audio playback

### ⚙️ Settings Screen
- Language toggle (English/Urdu)
- Simple switch interface
- App version information

## Design Principles

- **High Contrast**: Dark background with white text for maximum visibility
- **Large Fonts**: All text is sized for easy reading
- **Minimal Clutter**: Clean, simple interface
- **Clear Icons**: Visual indicators for all functions
- **Consistent Navigation**: Back and Home buttons on all screens

## Technical Specifications

- **Screen Size**: 1.3 inch
- **Touchscreen**: Yes
- **Physical Buttons**: One Home button (simulated in UI)
- **Framework**: Flutter
- **Minimum SDK**: Dart 3.0.0+

## Dependencies

- `flutter`: SDK
- `cupertino_icons`: ^1.0.6
- `vibration`: ^1.8.4 (for haptic feedback)
- `audioplayers`: ^5.2.1 (for audio playback)

## Getting Started

1. Ensure Flutter is installed and configured
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point and navigation
├── screens/
│   ├── home_screen.dart
│   ├── medicine_reminder_screen.dart
│   ├── panic_button_screen.dart
│   ├── health_monitoring_screen.dart
│   ├── audio_screen.dart
│   └── settings_screen.dart
├── widgets/
│   └── common_widgets.dart  # Reusable UI components
└── utils/
    └── app_localizations.dart  # Language support
```

## Notes

- This is a UI prototype. Real functionality (API calls, actual sensor readings, audio file playback) would need to be integrated in a production version.
- The app is optimized for portrait orientation on a small screen.
- All screens include both Back and Home navigation buttons for easy access.

## Future Enhancements

- Integration with actual health sensors
- Real-time medicine schedule from backend
- Emergency alert system integration
- Audio file management and playback
- Additional accessibility features
- Customizable font sizes
