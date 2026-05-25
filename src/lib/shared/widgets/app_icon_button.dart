import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AppIconButtonTone { primary, secondary, ghost, danger }

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.tone = AppIconButtonTone.secondary,
    this.isLoading = false,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppIconButtonTone tone;
  final bool isLoading;
  final double size;
  final double iconSize;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(tone);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: _enabled ? colors.border : AppColors.line),
    );

    final button = Material(
      color: _enabled ? colors.background : AppColors.hover,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _enabled ? onPressed : null,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.foreground,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: _enabled ? colors.foreground : AppColors.subtle,
                    size: iconSize,
                  ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }

  _ButtonColors _colors(AppIconButtonTone tone) {
    return switch (tone) {
      AppIconButtonTone.primary => const _ButtonColors(
          background: AppColors.ink,
          foreground: AppColors.background,
          border: AppColors.ink,
        ),
      AppIconButtonTone.secondary => const _ButtonColors(
          background: AppColors.hover,
          foreground: AppColors.ink,
          border: AppColors.line,
        ),
      AppIconButtonTone.ghost => const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.muted,
          border: Colors.transparent,
        ),
      AppIconButtonTone.danger => const _ButtonColors(
          background: AppColors.dangerSurface,
          foreground: AppColors.danger,
          border: AppColors.dangerSurface,
        ),
    };
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
