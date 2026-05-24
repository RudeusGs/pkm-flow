import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../workspaces/domain/workspace.dart';
import '../domain/inbox_models.dart';
import 'inbox_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.controller,
    this.workspaces = const <Workspace>[],
  });

  final InboxController controller;
  final List<Workspace> workspaces;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.controller.selectedConversation;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(conversation?.otherFullName ?? 'Chat'),
            actions: [
              if (widget.workspaces.isNotEmpty)
                IconButton(
                  tooltip: 'Chia sẻ workspace',
                  onPressed: () => _shareWorkspace(context),
                  icon: const Icon(Icons.ios_share),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.controller.messages.length,
                  itemBuilder: (context, index) {
                    final message = widget.controller.messages[index];
                    return Align(
                      alignment: message.isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .75),
                        decoration: BoxDecoration(
                          color: message.isMine
                              ? AppColors.accent
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: _MessageBubbleContent(
                          message: message,
                          onAcceptWorkspace: message.isMine
                              ? null
                              : () async {
                                  await widget.controller
                                      .acceptWorkspaceShare(message);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Đã tham gia workspace.')),
                                  );
                                },
                        ),
                      ),
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
                            style: const TextStyle(color: AppColors.muted)))),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          decoration:
                              const InputDecoration(hintText: 'Nhắn gì đó...'),
                          onChanged: (_) =>
                              widget.controller.publishTyping(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          final text = _text.text;
                          _text.clear();
                          await widget.controller.sendText(text);
                          await widget.controller.publishTyping(false);
                        },
                        icon: const Icon(Icons.send),
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

  Future<void> _shareWorkspace(BuildContext context) async {
    final result = await _showWorkspaceShareDialog(context, widget.workspaces);
    if (result == null) {
      return;
    }
    await widget.controller
        .sendWorkspaceShare(result.workspaceId, role: result.role);
  }
}

class _MessageBubbleContent extends StatelessWidget {
  const _MessageBubbleContent({required this.message, this.onAcceptWorkspace});

  final MessageItem message;
  final Future<void> Function()? onAcceptWorkspace;

  @override
  Widget build(BuildContext context) {
    final textColor = message.isMine ? Colors.white : AppColors.ink;
    if (message.type.toLowerCase().contains('workspace')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.space_dashboard_outlined, color: textColor, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.body.isEmpty ? 'Workspace invitation' : message.body,
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (onAcceptWorkspace != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: onAcceptWorkspace,
              icon: const Icon(Icons.check),
              label: const Text('Tham gia'),
            ),
          ],
        ],
      );
    }
    return Text(message.body, style: TextStyle(color: textColor));
  }
}

class _WorkspaceShareResult {
  const _WorkspaceShareResult({required this.workspaceId, required this.role});

  final String workspaceId;
  final String role;
}

Future<_WorkspaceShareResult?> _showWorkspaceShareDialog(
  BuildContext context,
  List<Workspace> workspaces,
) {
  var workspaceId = workspaces.first.id;
  var role = 'viewer';
  return showDialog<_WorkspaceShareResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Chia sẻ workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: workspaceId,
              decoration: const InputDecoration(labelText: 'Workspace'),
              items: workspaces
                  .map((workspace) => DropdownMenuItem(
                        value: workspace.id,
                        child: Text(workspace.name),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => workspaceId = value ?? workspaceId),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Quyền'),
              items: const [
                DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
              ],
              onChanged: (value) => setState(() => role = value ?? 'viewer'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _WorkspaceShareResult(workspaceId: workspaceId, role: role),
            ),
            child: const Text('Gửi'),
          ),
        ],
      ),
    ),
  );
}
