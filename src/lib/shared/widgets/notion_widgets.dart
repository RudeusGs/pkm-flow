import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NotionScaffold extends StatelessWidget {
  const NotionScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: ColoredBox(color: AppColors.background, child: body),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

class NotionTopBar extends StatelessWidget implements PreferredSizeWidget {
  const NotionTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.onTitleTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onTitleTap;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      titleSpacing: leading == null ? 16 : 0,
      leadingWidth: leading == null ? null : 56,
      leading: leading,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTitleTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        ...actions,
        const SizedBox(width: 6),
      ],
    );
  }
}

class NotionBottomNavItem {
  const NotionBottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class NotionBottomNav extends StatefulWidget {
  const NotionBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NotionBottomNavItem> items;

  @override
  State<NotionBottomNav> createState() => _NotionBottomNavState();
}

class _NotionBottomNavState extends State<NotionBottomNav> {
  int? _hoveredIndex;
  int? _pressedIndex;

  int get _focusIndex => _pressedIndex ?? _hoveredIndex ?? widget.selectedIndex;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line, width: .7)),
      ),
      child: SizedBox(
        height: 54 + bottomPadding,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = widget.items.length;
              final baseWidth = constraints.maxWidth / count;
              final focusedWidth =
                  (baseWidth * 1.22).clamp(baseWidth, baseWidth + 28);
              final otherWidth = count <= 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - focusedWidth) / (count - 1);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 190),
                      curve: Curves.easeOutCubic,
                      width: i == _focusIndex ? focusedWidth : otherWidth,
                      child: _NotionBottomNavButton(
                        item: widget.items[i],
                        selected: i == widget.selectedIndex,
                        focused: i == _focusIndex,
                        pressed: i == _pressedIndex,
                        onTap: () => widget.onSelected(i),
                        onHoverChanged: (value) =>
                            setState(() => _hoveredIndex = value ? i : null),
                        onPressedChanged: (value) =>
                            setState(() => _pressedIndex = value ? i : null),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotionBottomNavButton extends StatelessWidget {
  const _NotionBottomNavButton({
    required this.item,
    required this.selected,
    required this.focused,
    required this.pressed,
    required this.onTap,
    required this.onHoverChanged,
    required this.onPressedChanged,
  });

  final NotionBottomNavItem item;
  final bool selected;
  final bool focused;
  final bool pressed;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    final showLabel = selected || focused;
    final highlighted = selected || focused || pressed;
    final color = selected
        ? AppColors.ink
        : (highlighted ? AppColors.muted : AppColors.subtle);

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onTapDown: (_) => onPressedChanged(true),
        onTapCancel: () => onPressedChanged(false),
        onTapUp: (_) => onPressedChanged(false),
        child: Semantics(
          button: true,
          selected: selected,
          label: item.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            color: selected ? AppColors.hover : AppColors.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: selected ? 1 : 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: showLabel ? 1.05 : 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          color: color,
                          size: showLabel ? 21.5 : 21,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          child: showLabel
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10.5,
                                      height: 1,
                                      fontWeight: selected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotionTextField extends StatelessWidget {
  const NotionTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      style: const TextStyle(
          color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class NotionButton extends StatelessWidget {
  const NotionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.danger = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool danger;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = danger
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerSurface,
              foregroundColor: AppColors.danger,
            ),
            child: child,
          )
        : secondary
            ? OutlinedButton(onPressed: onPressed, child: child)
            : FilledButton(onPressed: onPressed, child: child);

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class NotionCard extends StatelessWidget {
  const NotionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? AppColors.hover : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.muted : AppColors.line),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class NotionListTile extends StatelessWidget {
  const NotionListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textColor = !enabled
        ? AppColors.subtle
        : (danger ? AppColors.danger : AppColors.ink);
    return NotionCard(
      padding: EdgeInsets.zero,
      onTap: enabled ? onTap : null,
      child: ListTile(
        enabled: enabled,
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: leading,
        title: Text(
          title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
        trailing: trailing,
      ),
    );
  }
}

class NotionBottomSheet extends StatelessWidget {
  const NotionBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    bool isScrollControlled = true,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 0, 20, 24),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      builder: (context) => NotionBottomSheet(
        title: title,
        subtitle: subtitle,
        padding: padding,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BottomSheetHeader(title: title, subtitle: subtitle),
            child,
          ],
        ),
      ),
    );
  }
}

class NotionActionRow extends StatelessWidget {
  const NotionActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.subtle
        : (danger ? AppColors.danger : AppColors.ink);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12, height: 1.25),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class NotionEmptyState extends StatelessWidget {
  const NotionEmptyState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(icon, size: 28, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class NotionConfirmDialog extends StatelessWidget {
  const NotionConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.danger = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NotionConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.dangerSurface,
                  foregroundColor: AppColors.danger,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class NotionSection extends StatelessWidget {
  const NotionSection({
    super.key,
    required this.title,
    this.action,
    required this.children,
  });

  final String title;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class NotionActionTile extends StatelessWidget {
  const NotionActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return NotionListTile(
      onTap: onTap,
      danger: danger,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: danger ? AppColors.dangerSurface : AppColors.hover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  danger ? AppColors.danger.withOpacity(.28) : AppColors.line),
        ),
        child: Icon(icon,
            size: 20, color: danger ? AppColors.danger : AppColors.ink),
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}

class NotionPill extends StatelessWidget {
  const NotionPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
        ],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: IconTheme(
          data: IconThemeData(
              color: selected ? AppColors.background : AppColors.ink),
          child: DefaultTextStyle.merge(
            style: TextStyle(
                color: selected ? AppColors.background : AppColors.ink),
            child: child,
          ),
        ),
      ),
    );
  }
}

class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
