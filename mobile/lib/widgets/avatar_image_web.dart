import 'dart:convert';
import 'package:flutter/material.dart';

/// Builds avatar image from base64. Used on web (no dart:io).
Widget buildAvatarImage({
  required String? imagePath,
  required String? imageBase64,
  required double size,
  required IconData defaultIcon,
  required Color iconColor,
}) {
  if (imageBase64 == null || imageBase64.isEmpty) {
    return Center(child: Icon(defaultIcon, size: size * 0.55, color: iconColor));
  }
  try {
    final bytes = base64Decode(imageBase64);
    return ClipOval(
      child: Image.memory(
        bytes,
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
  } catch (_) {
    return Center(child: Icon(defaultIcon, size: size * 0.55, color: iconColor));
  }
}
