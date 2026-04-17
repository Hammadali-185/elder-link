import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Custom staff avatar images keyed by Firebase UID (no passwords).
class StaffAvatarLocal {
  static const String keyCustomAvatars = 'staff_user_custom_avatars';

  static Map<String, dynamic> _loadMap(SharedPreferences prefs) {
    final s = prefs.getString(keyCustomAvatars);
    if (s == null || s.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMap(SharedPreferences prefs, Map<String, dynamic> m) async {
    await prefs.setString(keyCustomAvatars, jsonEncode(m));
  }

  /// Preview map for [AvatarWidget] / [StaffAccountAvatar].
  static Future<Map<String, dynamic>> getPreview(
    SharedPreferences prefs,
    String firebaseUid,
    String avatarPreset,
  ) async {
    final uid = firebaseUid.trim();
    if (uid.isEmpty) {
      return {'type': 'neutral', 'imagePath': null, 'imageBase64': null};
    }
    final preset = avatarPreset.trim().isEmpty ? 'neutral' : avatarPreset;
    if (preset == 'custom') {
      final m = _loadMap(prefs);
      final entry = m[uid];
      if (entry is Map) {
        final path = entry['path'] as String?;
        final b64 = entry['base64'] as String?;
        return {
          'type': 'custom',
          'imagePath': path,
          'imageBase64': b64,
        };
      }
      return {'type': 'custom', 'imagePath': null, 'imageBase64': null};
    }
    // neutral, male, female (legacy), or unknown → same on-screen treatment
    return {'type': 'neutral', 'imagePath': null, 'imageBase64': null};
  }

  static Future<void> copyGlobalPickedImageToUid(
    SharedPreferences prefs,
    String firebaseUid,
  ) async {
    final key = firebaseUid.trim();
    if (key.isEmpty) return;
    final path = prefs.getString('staff_avatar_image_path');
    final b64 = prefs.getString('staff_avatar_image_base64');
    final m = _loadMap(prefs);
    if (path != null && path.isNotEmpty) {
      m[key] = {'path': path};
      await _saveMap(prefs, m);
    } else if (b64 != null && b64.isNotEmpty) {
      m[key] = {'base64': b64};
      await _saveMap(prefs, m);
    }
  }

  static Future<void> restoreUidCustomAvatarToGlobalPrefs(
    SharedPreferences prefs,
    String firebaseUid,
  ) async {
    final key = firebaseUid.trim();
    final m = _loadMap(prefs);
    final entry = m[key];
    if (entry is! Map) {
      await prefs.remove('staff_avatar_image_path');
      await prefs.remove('staff_avatar_image_base64');
      return;
    }
    final path = entry['path'] as String?;
    final b64 = entry['base64'] as String?;
    if (path != null && path.isNotEmpty) {
      await prefs.setString('staff_avatar_image_path', path);
      await prefs.remove('staff_avatar_image_base64');
    } else if (b64 != null && b64.isNotEmpty) {
      await prefs.setString('staff_avatar_image_base64', b64);
      await prefs.remove('staff_avatar_image_path');
    } else {
      await prefs.remove('staff_avatar_image_path');
      await prefs.remove('staff_avatar_image_base64');
    }
  }
}
