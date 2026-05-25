import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AppSnackTone { success, error, info, warning }

class AppSnackBar {
  const AppSnackBar._();

  static void success(BuildContext context, String message) {
    show(context, message, tone: AppSnackTone.success);
  }

  static void error(
    BuildContext context,
    Object? error, {
    String fallback = 'Không thao tác được.',
  }) {
    show(
      context,
      cleanError(error, fallback: fallback),
      tone: AppSnackTone.error,
    );
  }

  static void info(BuildContext context, String message) {
    show(context, message, tone: AppSnackTone.info);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, tone: AppSnackTone.warning);
  }

  static void show(
    BuildContext context,
    String message, {
    AppSnackTone tone = AppSnackTone.info,
  }) {
    if (!context.mounted) return;

    final cleanMessage = cleanError(message, fallback: message);
    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: _background(tone),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _border(tone)),
        ),
        content: Row(
          children: [
            Icon(_icon(tone), color: _foreground(tone), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cleanMessage,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _foreground(tone),
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String cleanError(
    Object? error, {
    String fallback = 'Không thao tác được.',
  }) {
    final raw = (error?.toString() ?? '').trim();
    if (raw.isEmpty) return fallback;

    var text = raw
        .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^ApiFailure:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^DioException\s*\[.*?\]:\s*', caseSensitive: false), '')
        .trim();

    final lower = text.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('permission') ||
        lower.contains('không có quyền') ||
        lower.contains('khong co quyen') ||
        lower.contains('manageforbidden') ||
        lower.contains('createforbidden') ||
        lower.contains('readforbidden') ||
        lower.contains('forbidden')) {
      return 'Không có quyền thực hiện thao tác này.';
    }

    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Bạn cần đăng nhập lại.';
    }

    if (lower.contains('traceid') ||
        lower.contains('status code') ||
        lower.contains('statuscode') ||
        lower.contains('system.') ||
        lower.contains('dioexception') ||
        lower.contains('stack trace') ||
        lower.length > 180) {
      return fallback;
    }

    return text.isEmpty ? fallback : text;
  }

  static IconData _icon(AppSnackTone tone) {
    return switch (tone) {
      AppSnackTone.success => Icons.check_circle_rounded,
      AppSnackTone.error => Icons.error_outline_rounded,
      AppSnackTone.warning => Icons.warning_amber_rounded,
      AppSnackTone.info => Icons.info_outline_rounded,
    };
  }

  static Color _background(AppSnackTone tone) {
    return switch (tone) {
      AppSnackTone.success => const Color(0xFF132118),
      AppSnackTone.error => AppColors.dangerSurface,
      AppSnackTone.warning => const Color(0xFF241C0F),
      AppSnackTone.info => AppColors.hover,
    };
  }

  static Color _border(AppSnackTone tone) {
    return switch (tone) {
      AppSnackTone.success => AppColors.success.withOpacity(.34),
      AppSnackTone.error => AppColors.danger.withOpacity(.34),
      AppSnackTone.warning => AppColors.warning.withOpacity(.34),
      AppSnackTone.info => AppColors.line,
    };
  }

  static Color _foreground(AppSnackTone tone) {
    return switch (tone) {
      AppSnackTone.success => AppColors.success,
      AppSnackTone.error => AppColors.danger,
      AppSnackTone.warning => AppColors.warning,
      AppSnackTone.info => AppColors.ink,
    };
  }
}
