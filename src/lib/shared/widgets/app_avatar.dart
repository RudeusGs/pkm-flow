import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/image_url.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.backgroundColor = AppColors.soft,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = resolveImageUrl(imageUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundColor: AppColors.ink,
      backgroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      child: url == null || url.isEmpty
          ? Text(
              initials(name),
              style: TextStyle(fontSize: radius * .55, fontWeight: FontWeight.w900),
            )
          : null,
    );
  }

  static String initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return '?';
    return parts.map((part) => part.characters.first.toUpperCase()).join();
  }
}
