import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/staff_users_storage.dart';
import 'avatar_image_io.dart' if (dart.library.html) 'avatar_image_web.dart'
    as avatar_image;

/// Avatar for a stored [StaffUser] (not necessarily the active session).
class StaffAccountAvatar extends StatelessWidget {
  final StaffUser user;
  final double size;

  const StaffAccountAvatar({
    super.key,
    required this.user,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        final avatarType = snapshot.data?['type'] ?? 'male';
        final imagePath = snapshot.data?['imagePath'] as String?;
        final imageBase64 = snapshot.data?['imageBase64'] as String?;
        final isMale = avatarType == 'male';
        final isCustom = avatarType == 'custom';
        final Color bgColor = (imagePath == null || imagePath.isEmpty) &&
                (imageBase64 == null || imageBase64.isEmpty)
            ? (isCustom
                ? Colors.grey.withOpacity(0.2)
                : (isMale
                    ? Colors.blue.withOpacity(0.25)
                    : Colors.pink.withOpacity(0.25)))
            : Colors.transparent;
        final Color iconColor = isCustom
            ? Colors.grey.shade700
            : (isMale ? Colors.blue.shade800 : Colors.pink.shade700);
        final IconData defaultIcon =
            isCustom ? Icons.person : (isMale ? Icons.man : Icons.woman);
        final Color borderColor = (imagePath == null || imagePath.isEmpty) &&
                (imageBase64 == null || imageBase64.isEmpty)
            ? (isCustom ? Colors.grey : (isMale ? Colors.blue : Colors.pink))
            : Colors.white;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: avatar_image.buildAvatarImage(
            imagePath: imagePath,
            imageBase64: imageBase64,
            size: size,
            defaultIcon: defaultIcon,
            iconColor: iconColor,
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return StaffUsersStorage.getUserAvatarPreview(prefs, user);
  }
}
