import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'inbox_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.controller});

  final InboxController controller;

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
          appBar: AppBar(title: Text(conversation?.otherFullName ?? 'Chat')),
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
                        child: Text(message.body,
                            style: TextStyle(
                                color: message.isMine
                                    ? Colors.white
                                    : AppColors.ink)),
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
}
