import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/notion_widgets.dart';
import 'auth_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1200,
    );
    if (image == null) return;
    final ok = await widget.authController.uploadAvatar(image);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Avatar updated.'
              : widget.authController.error ?? 'Could not update avatar.')),
    );
  }

  Future<void> _editProfile() async {
    final user = widget.authController.user;
    final fullName = TextEditingController(text: user?.fullName ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BottomSheetHeader(
              title: 'Edit profile',
              subtitle: 'Change the name people see in workspaces and chat.',
            ),
            NotionTextField(
              controller: fullName,
              autofocus: true,
              labelText: 'Full name',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.pop(context, true),
            ),
            const SizedBox(height: 18),
            NotionButton(
              label: 'Save profile',
              icon: Icons.done_rounded,
              expanded: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );

    if (ok == true && fullName.text.trim().isNotEmpty) {
      final saved =
          await widget.authController.updateProfile(fullName.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(saved
                ? 'Profile saved.'
                : widget.authController.error ?? 'Could not save profile.')),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BottomSheetHeader(
              title: 'Change password',
              subtitle: 'Update the password used for this account.',
            ),
            NotionTextField(
              controller: currentPassword,
              autofocus: true,
              obscureText: true,
              labelText: 'Current password',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            NotionTextField(
              controller: newPassword,
              obscureText: true,
              labelText: 'New password',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            NotionTextField(
              controller: confirmPassword,
              obscureText: true,
              labelText: 'Confirm new password',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.pop(context, true),
            ),
            const SizedBox(height: 18),
            NotionButton(
              label: 'Update password',
              icon: Icons.lock_reset_rounded,
              expanded: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final current = currentPassword.text;
    final next = newPassword.text;
    final confirm = confirmPassword.text;

    if (current.trim().isEmpty || next.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both current and new password.')),
      );
      return;
    }

    if (next != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New password confirmation does not match.')),
      );
      return;
    }

    final saved = await widget.authController.changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Password updated.'
            : widget.authController.error ?? 'Could not update password.'),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await NotionConfirmDialog.show(
      context: context,
      title: 'Logout?',
      message: 'You can log back in any time.',
      confirmLabel: 'Logout',
      danger: true,
    );
    if (confirmed) await widget.authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final user = widget.authController.user;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
          children: [
            NotionCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      AppAvatar(
                        name: user?.fullName ?? 'User',
                        imageUrl: user?.avatarUrl,
                        radius: 48,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: IconButton.filled(
                          tooltip: 'Change avatar',
                          onPressed:
                              widget.authController.isBusy ? null : _pickAvatar,
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.fullName ?? 'User',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 28,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '@${user?.userName ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.muted, fontWeight: FontWeight.w700),
                  ),
                  if (user?.email.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      user!.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.subtle),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: NotionButton(
                          label: 'Edit name',
                          icon: Icons.edit_outlined,
                          onPressed: widget.authController.isBusy
                              ? null
                              : _editProfile,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NotionButton(
                          label: 'Photo',
                          icon: Icons.image_outlined,
                          secondary: true,
                          onPressed:
                              widget.authController.isBusy ? null : _pickAvatar,
                        ),
                      ),
                    ],
                  ),
                  if (widget.authController.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.authController.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.danger, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            NotionActionTile(
              icon: Icons.person_outline_rounded,
              title: 'Account',
              subtitle: 'Name, email, and avatar.',
              onTap: _editProfile,
            ),
            const SizedBox(height: 10),
            NotionActionTile(
              icon: Icons.lock_outline_rounded,
              title: 'Security',
              subtitle: 'Change your account password.',
              onTap: widget.authController.isBusy ? null : _changePassword,
            ),
            const SizedBox(height: 10),
            NotionActionTile(
              icon: Icons.logout_rounded,
              title: 'Logout',
              subtitle: 'End this session on this device.',
              danger: true,
              onTap: widget.authController.isBusy ? null : _confirmLogout,
            ),
          ],
        );
      },
    );
  }
}
