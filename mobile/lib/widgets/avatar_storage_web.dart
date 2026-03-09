import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

const _keyPath = 'staff_avatar_image_path';
const _keyBase64 = 'staff_avatar_image_base64';

Future<Uint8List?> loadAvatarBytes(SharedPreferences prefs) async {
  try {
    final base64 = prefs.getString(_keyBase64);
    if (base64 == null || base64.isEmpty) return null;
    return base64Decode(base64);
  } catch (_) {
    return null;
  }
}

Future<void> savePickedImage(XFile image, SharedPreferences prefs) async {
  try {
    final bytes = await image.readAsBytes();
    final base64 = base64Encode(bytes);
    await prefs.setString(_keyBase64, base64);
    await prefs.setString('staff_avatar', 'custom');
  } catch (e) {
    rethrow;
  }
}
