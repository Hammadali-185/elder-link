import 'package:flutter/material.dart';

class AppLocalizations extends InheritedWidget {
  final String language;
  final Widget child;

  const AppLocalizations({
    Key? key,
    required this.language,
    required this.child,
  }) : super(key: key, child: child);

  static AppLocalizations of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocalizations>() ??
        const AppLocalizations(
          language: 'English',
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(AppLocalizations oldWidget) {
    return language != oldWidget.language;
  }

  // Home Screen
  String get medicineReminder =>
      language == 'Urdu' ? 'دوا یاد دہانی' : 'Medicine Reminder';
  String get panicButton => language == 'Urdu' ? 'ہنگامی بٹن' : 'Panic Button';
  String get healthMonitoring =>
      language == 'Urdu' ? 'صحت کی نگرانی' : 'Health Monitoring';
  String get audio => language == 'Urdu' ? 'آڈیو' : 'Audio';
  String get settings => language == 'Urdu' ? 'ترتیبات' : 'Settings';

  // Common
  String get back => language == 'Urdu' ? 'واپس' : 'BACK';
  String get home => language == 'Urdu' ? 'ہوم' : 'HOME';

  // Medicine Reminder
  String get taken => language == 'Urdu' ? 'لیا' : 'TAKEN';
  String get snooze => language == 'Urdu' ? 'ملتوی' : 'SNOOZE';
  String get missed => language == 'Urdu' ? 'چھوٹ گیا' : 'MISSED';
  String get medicineName => language == 'Urdu' ? 'دوا کا نام' : 'Medicine Name';
  String get dosage => language == 'Urdu' ? 'خوراک' : 'Dosage';
  String get time => language == 'Urdu' ? 'وقت' : 'Time';

  // Panic Button
  String get pressAndHold => language == 'Urdu' ? 'دبائیں اور تھامیں' : 'PRESS & HOLD';
  String get alertSent => language == 'Urdu' ? 'الرٹ بھیج دیا گیا' : 'Alert Sent';

  // Health Monitoring
  String get heartRate => language == 'Urdu' ? 'دل کی دھڑکن' : 'Heart Rate';
  String get bloodPressure => language == 'Urdu' ? 'بلڈ پریشر' : 'Blood Pressure';
  String get startReading => language == 'Urdu' ? 'پڑھنا شروع کریں' : 'START READING';
  String get bpm => language == 'Urdu' ? 'بی پی ایم' : 'BPM';
  String get mmhg => language == 'Urdu' ? 'ایم ایم ایچ جی' : 'mmHg';
  String get warning => language == 'Urdu' ? 'انتباہ' : 'WARNING';
  String get abnormalReading =>
      language == 'Urdu' ? 'غیر معمولی پڑھائی' : 'Abnormal Reading';

  // Audio
  String get play => language == 'Urdu' ? 'چلائیں' : 'PLAY';
  String get pause => language == 'Urdu' ? 'روکیں' : 'PAUSE';
  String get stop => language == 'Urdu' ? 'بند کریں' : 'STOP';
  String get currentTrack => language == 'Urdu' ? 'موجودہ ٹریک' : 'Current Track';

  // Settings
  String get languageLabel => language == 'Urdu' ? 'زبان' : 'Language';
  String get english => language == 'Urdu' ? 'انگریزی' : 'English';
  String get urdu => language == 'Urdu' ? 'اردو' : 'Urdu';
}
