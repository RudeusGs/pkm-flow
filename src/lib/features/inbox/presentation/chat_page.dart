import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/image_url.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/inbox_models.dart';
import 'inbox_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.controller,
    this.workspaces = const [],
    this.onWorkspaceOpened,
  });

  final InboxController controller;
  final List<Workspace> workspaces;
  final Future<void> Function(Workspace workspace)? onWorkspaceOpened;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _maxImageBytes = 8 * 1024 * 1024;

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  Timer? _typingTimer;
  bool _typingActive = false;
  bool _sending = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_sending) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    if (bytes.length > _maxImageBytes) {
      AppSnackBar.warning(context, 'Ảnh tối đa 8MB. Chọn ảnh nhẹ hơn nha.');
      return;
    }

    setState(() {
      _selectedImage = picked;
      _selectedImageBytes = bytes;
    });
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _send() async {
    if (_sending) return;

    final image = _selectedImage;
    final bytes = _selectedImageBytes;
    final text = _text.text.trim();

    if ((image == null || bytes == null) && text.isEmpty) return;

    setState(() => _sending = true);
    _text.clear();
    _clearSelectedImage();

    try {
      if (image != null && bytes != null) {
        await widget.controller.sendImage(
          bytes: bytes,
          fileName: image.name,
          contentType: image.mimeType,
          caption: text,
        );
      } else {
        await widget.controller.sendText(text);
      }
      await widget.controller.publishTyping(false);
      _scrollToBottom();
    } catch (err) {
      if (!mounted) return;
      AppSnackBar.error(context, err);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _handleTyping(String value) {
    if (!_typingActive) {
      _typingActive = true;
      unawaited(widget.controller.publishTyping(true));
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1200), () {
      _typingActive = false;
      unawaited(widget.controller.publishTyping(false));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final conversation = widget.controller.selectedConversation;
        final messageCount = widget.controller.messages.length;
        if (messageCount != _lastMessageCount) {
          _lastMessageCount = messageCount;
          _scrollToBottom();
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: conversation == null
                ? const Text('Chat')
                : Row(
                    children: [
                      AppAvatar(
                          name: conversation.otherFullName,
                          imageUrl: conversation.otherAvatarUrl,
                          radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(conversation.otherFullName,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('@${conversation.otherUserName}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          body: Column(
            children: [
              Expanded(
                child: widget.controller.messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Hãy gửi tin nhắn đầu tiên.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        itemCount: widget.controller.messages.length,
                        itemBuilder: (context, index) {
                          final message = widget.controller.messages[index];
                          return _MessageBubble(
                            message: message,
                            onAcceptWorkspaceShare: message.isMine ||
                                    !message.isWorkspaceShare
                                ? null
                                : () async {
                                    final workspace = await widget.controller
                                        .acceptWorkspaceShare(message);
                                    if (!context.mounted) return;

                                    if (widget.onWorkspaceOpened != null) {
                                      await widget.onWorkspaceOpened!(workspace);
                                      if (context.mounted) {
                                        await Navigator.of(context).maybePop();
                                      }
                                      return;
                                    }

                                    AppSnackBar.success(
                                      context,
                                      'Đã mở workspace "${workspace.name}".',
                                    );
                                  },
                          );
                        },
                      ),
              ),
              if (widget.controller.typingText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 6),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(widget.controller.typingText!,
                          style: const TextStyle(color: AppColors.muted))),
                ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedImage != null && _selectedImageBytes != null)
                        _SelectedImagePreview(
                          name: _selectedImage!.name,
                          bytes: _selectedImageBytes!,
                          onClear: _clearSelectedImage,
                        ),
                      Row(
                        children: [
                          AppIconButton(
                            tooltip: 'Gửi ảnh',
                            tone: AppIconButtonTone.secondary,
                            onPressed: _sending ? null : _pickImage,
                            icon: Icons.image_outlined,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _text,
                              minLines: 1,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: _selectedImage == null
                                    ? 'Message...'
                                    : 'Caption for image...',
                                filled: true,
                              ),
                              onChanged: _handleTyping,
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppIconButton(
                            tooltip: 'Gửi tin nhắn',
                            tone: AppIconButtonTone.primary,
                            isLoading:
                                _sending || widget.controller.isSendingMessage,
                            onPressed:
                                _sending || widget.controller.isSendingMessage
                                    ? null
                                    : _send,
                            icon: Icons.send_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.name,
    required this.bytes,
    required this.onClear,
  });

  final String name;
  final Uint8List bytes;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes, width: 46, height: 46, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppIconButton(
            tooltip: 'Bỏ ảnh',
            tone: AppIconButtonTone.ghost,
            onPressed: onClear,
            icon: Icons.close_rounded,
            size: 38,
            iconSize: 19,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onAcceptWorkspaceShare});

  final MessageItem message;
  final VoidCallback? onAcceptWorkspaceShare;

  @override
  Widget build(BuildContext context) {
    final share = message.workspaceShare;
    final isShare = message.isWorkspaceShare && share != null;
    final hasImage = message.imageUrl?.isNotEmpty == true;
    final alignment =
        message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isMine ? AppColors.ink : AppColors.surface;
    final textColor = message.isMine ? AppColors.background : AppColors.ink;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(
          horizontal: hasImage ? 7 : 14,
          vertical: hasImage ? 7 : 10,
        ),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .80),
        decoration: BoxDecoration(
          color: isShare ? AppColors.surface : bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isMine ? 18 : 6),
            bottomRight: Radius.circular(message.isMine ? 6 : 18),
          ),
          border: Border.all(
              color: isShare
                  ? AppColors.line
                  : (message.isMine ? AppColors.ink : AppColors.line)),
        ),
        child: isShare
            ? _WorkspaceShareMessage(
                payload: share,
                isMine: message.isMine,
                onAccept: onAcceptWorkspaceShare)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .42,
                          minWidth: 160,
                        ),
                        child: Image.network(
                          resolveImageUrl(message.imageUrl) ?? message.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 220,
                            height: 120,
                            color: AppColors.background,
                            alignment: Alignment.center,
                            child: const Text(
                              'Không tải được ảnh',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (message.body.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.body.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hasImage ? 5 : 0),
                      child: Text(message.body,
                          style: TextStyle(color: textColor, height: 1.35)),
                    ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hasImage ? 5 : 0),
                    child: Text(shortDate(message.createdDate),
                        style: TextStyle(
                            fontSize: 10,
                            color: message.isMine
                                ? AppColors.subtle
                                : AppColors.muted)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WorkspaceShareMessage extends StatelessWidget {
  const _WorkspaceShareMessage(
      {required this.payload, required this.isMine, this.onAccept});

  final WorkspaceSharePayload payload;
  final bool isMine;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Text(
                      payload.workspaceName.characters.first.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.background,
                          fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Workspace invite',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700)),
                  Text(payload.workspaceName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                  if (payload.workspaceDescription?.trim().isNotEmpty == true)
                    Text(payload.workspaceDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Text(
                      '${payload.workspaceVisibility.toLowerCase() == 'public' ? 'Public' : 'Private'} · ${payload.grantedRole}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isMine)
          const Text('You shared this workspace.',
              style: TextStyle(color: AppColors.muted))
        else
          FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Open workspace')),
      ],
    );
  }
}