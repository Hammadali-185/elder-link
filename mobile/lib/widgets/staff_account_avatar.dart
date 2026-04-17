import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../admin/staff_display_profile.dart';
import '../services/staff_avatar_local.dart';
import 'avatar_image_io.dart' if (dart.library.html) 'avatar_image_web.dart'
    as avatar_image;

/// Avatar for a [StaffDisplayProfile] (e.g. admin roster row).
class StaffAccountAvatar extends StatelessWidget {
  final StaffDisplayProfile profile;
  final double size;

  const StaffAccountAvatar({
    super.key,
    required this.profile,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        final avatarType = snapshot.data?['type'] ?? 'neutral';
        final imagePath = snapshot.data?['imagePath'] as String?;
        final imageBase64 = snapshot.data?['imageBase64'] as String?;
        final isCustom = avatarType == 'custom';
        final Color bgColor = (imagePath == null || imagePath.isEmpty) &&
                (imageBase64 == null || imageBase64.isEmpty)
            ? (isCustom
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.blueGrey.withValues(alpha: 0.14))
            : Colors.transparent;
        final Color iconColor =
            isCustom ? Colors.grey.shade700 : Colors.blueGrey.shade800;
        const IconData defaultIcon = Icons.person;
        final Color borderColor = (imagePath == null || imagePath.isEmpty) &&
                (imageBase64 == null || imageBase64.isEmpty)
            ? (isCustom ? Colors.grey : Colors.blueGrey.shade300)
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
                color: Colors.black.withValues(alpha: 0.1),
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
    return StaffAvatarLocal.getPreview(prefs, profile.id, profile.avatarPreset);
  }
}
