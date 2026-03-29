import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const _keyPath = 'staff_avatar_image_path';

Future<Uint8List?> loadAvatarBytes(SharedPreferences prefs) async {
  try {
    final path = prefs.getString(_keyPath);
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> savePickedImage(XFile image, SharedPreferences prefs) async {
  try {
    Directory? directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (_) {
      try {
        directory = await getTemporaryDirectory();
      } catch (_) {}
    }
    if (directory != null) {
      final fileName = 'staff_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await File(image.path).copy('${directory.path}/$fileName');
      await prefs.setString(_keyPath, saved.path);
    } else {
      await prefs.setString(_keyPath, image.path);
    }
  } catch (e) {
    rethrow;
  }
}
