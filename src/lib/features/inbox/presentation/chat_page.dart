import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/image_url.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/inbox_models.dart';
import 'inbox_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage(
      {super.key, required this.controller, this.workspaces = const []});

  final InboxController controller;
  final List<Workspace> workspaces;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _typingTimer;
  bool _typingActive = false;
  bool _sending = false;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    final text = _text.text;
    setState(() => _sending = true);
    _text.clear();
    try {
      await widget.controller.sendText(text);
      await widget.controller.publishTyping(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients)
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut);
      });
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final conversation = widget.controller.selectedConversation;
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
                child: ListView.builder(
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Opened "${workspace.name}".')));
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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                              hintText: 'Message...', filled: true),
                          onChanged: _handleTyping,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onAcceptWorkspaceShare});

  final MessageItem message;
  final VoidCallback? onAcceptWorkspaceShare;

  @override
  Widget build(BuildContext context) {
    final share = message.workspaceShare;
    final isShare = message.isWorkspaceShare && share != null;
    final alignment =
        message.isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isMine ? AppColors.ink : AppColors.surface;
    final textColor = message.isMine ? AppColors.background : AppColors.ink;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  if (message.imageUrl?.isNotEmpty == true) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                          resolveImageUrl(message.imageUrl) ??
                              message.imageUrl!,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (message.body.isNotEmpty)
                    Text(message.body,
                        style: TextStyle(color: textColor, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(shortDate(message.createdDate),
                      style: TextStyle(
                          fontSize: 10,
                          color: message.isMine
                              ? AppColors.subtle
                              : AppColors.muted)),
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
