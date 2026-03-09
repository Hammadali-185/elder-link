import 'dart:io';
import 'package:flutter/material.dart';

/// Builds avatar image from file path. Used on mobile/desktop only (dart:io available).
Widget buildAvatarImage({
  required String? imagePath,
  required String? imageBase64,
  required double size,
  required IconData defaultIcon,
  required Color iconColor,
}) {
  if (imagePath == null || imagePath.isEmpty) {
    return Center(child: Icon(defaultIcon, size: size * 0.55, color: iconColor));
  }
  final file = File(imagePath);
  if (!file.existsSync()) {
    return Center(child: Icon(defaultIcon, size: size * 0.55, color: iconColor));
  }
  return ClipOval(
    child: Image.file(
      file,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(defaultIcon, size: size * 0.55, color: iconColor),
        );
      },
    ),
  );
}
