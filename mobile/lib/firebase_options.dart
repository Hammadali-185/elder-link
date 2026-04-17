// ignore_for_file: lines_longer_than_80_chars
//
// Replace with output from: dart pub global activate flutterfire_cli && flutterfire configure
// Some values may be filled manually from Firebase console config files; prefer flutterfire for full parity.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WEB_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'elderlink-app',
    authDomain: 'elderlink-app.firebaseapp.com',
    storageBucket: 'elderlink-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCvdYPimXKeCyjQudG7ZCdHCOnJTN-wwgM',
    appId: '1:273142809621:android:3b6bcc4ae1b76d9382fa1c',
    messagingSenderId: '273142809621',
    projectId: 'elderlink-371ba',
    storageBucket: 'elderlink-371ba.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_IOS_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'elderlink-app',
    storageBucket: 'elderlink-app.firebasestorage.app',
    iosBundleId: 'com.elderlink.mobile',
  );
}
