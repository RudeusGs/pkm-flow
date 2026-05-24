import 'package:flutter/material.dart';

import 'notion_widgets.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return NotionEmptyState(
      icon: icon,
      title: title,
      message: message,
      action: action,
    );
  }
}
