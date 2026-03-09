import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'avatar_image_io.dart' if (dart.library.html) 'avatar_image_web.dart' as avatar_image;

class AvatarWidget extends StatelessWidget {
  final double size;
  final String? staffName;

  const AvatarWidget({
    super.key,
    this.size = 40,
    this.staffName,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getAvatarData(),
      builder: (context, snapshot) {
        final avatarType = snapshot.data?['type'] ?? 'male';
        final imagePath = snapshot.data?['imagePath'] as String?;
        final imageBase64 = snapshot.data?['imageBase64'] as String?;
        final isMale = avatarType == 'male';
        final isFemale = avatarType == 'female';
        final isCustom = avatarType == 'custom';
        final Color bgColor = (imagePath == null && imageBase64 == null)
            ? (isCustom
                ? Colors.grey.withOpacity(0.2)
                : (isMale ? Colors.blue.withOpacity(0.25) : Colors.pink.withOpacity(0.25)))
            : Colors.transparent;
        final Color iconColor = isCustom
            ? Colors.grey.shade700
            : (isMale ? Colors.blue.shade800 : Colors.pink.shade700);
        final IconData defaultIcon =
            isCustom ? Icons.person : (isMale ? Icons.man : Icons.woman);
        final Color borderColor = (imagePath == null && imageBase64 == null)
            ? (isCustom ? Colors.grey : (isMale ? Colors.blue : Colors.pink))
            : Colors.white;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
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

  Future<Map<String, dynamic>> _getAvatarData() async {
    final prefs = await SharedPreferences.getInstance();
    final avatarType = prefs.getString('staff_avatar') ?? 'male';
    final imagePath = prefs.getString('staff_avatar_image_path');
    final imageBase64 = prefs.getString('staff_avatar_image_base64');
    return {
      'type': avatarType,
      'imagePath': imagePath,
      'imageBase64': imageBase64,
    };
  }
}
