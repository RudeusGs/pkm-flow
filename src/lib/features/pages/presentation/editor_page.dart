import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/block_item.dart';
import '../domain/page_item.dart';
import 'pages_controller.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.controller, required this.page});

  final PagesController controller;
  final PageItem page;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadDocument(widget.page);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
                widget.controller.selectedPage?.title ?? widget.page.title),
            actions: [
              PopupMenuButton<String>(
                onSelected: widget.controller.addBlock,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'paragraph', child: Text('Paragraph')),
                  PopupMenuItem(value: 'heading_1', child: Text('Heading 1')),
                  PopupMenuItem(value: 'todo', child: Text('Todo')),
                  PopupMenuItem(
                      value: 'bulleted_list', child: Text('Bullet list')),
                  PopupMenuItem(value: 'quote', child: Text('Quote')),
                  PopupMenuItem(value: 'code', child: Text('Code')),
                ],
              ),
            ],
          ),
          body: widget.controller.isLoading && widget.controller.blocks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: widget.controller.blocks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                            widget.controller.selectedPage?.title ??
                                widget.page.title,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink)),
                      );
                    }
                    final block = widget.controller.blocks[index - 1];
                    final lease = widget.controller.leases[block.id];
                    return BlockEditorTile(
                      block: block,
                      leaseLabel: lease?.isHeldByCurrentUser == true
                          ? 'Bạn đang sửa'
                          : lease?.holderDisplayName == null
                              ? null
                              : '${lease!.holderDisplayName} đang sửa',
                      canEdit: lease?.isHeldByCurrentUser != false,
                      onFocus: () => widget.controller.acquireLease(block),
                      onBlur: () => widget.controller.releaseLease(block),
                      onChanged: (type, text) =>
                          widget.controller.updateBlock(block, type, text),
                      onDraft: (text) =>
                          widget.controller.sendDraft(block, text),
                      onDelete: () => widget.controller.deleteBlock(block),
                    );
                  },
                ),
        );
      },
    );
  }
}

class BlockEditorTile extends StatefulWidget {
  const BlockEditorTile({
    super.key,
    required this.block,
    required this.canEdit,
    required this.onFocus,
    required this.onBlur,
    required this.onChanged,
    required this.onDraft,
    required this.onDelete,
    this.leaseLabel,
  });

  final BlockItem block;
  final bool canEdit;
  final String? leaseLabel;
  final Future<bool> Function() onFocus;
  final Future<void> Function() onBlur;
  final Future<void> Function(String type, String text) onChanged;
  final Future<void> Function(String text) onDraft;
  final Future<void> Function() onDelete;

  @override
  State<BlockEditorTile> createState() => _BlockEditorTileState();
}

class _BlockEditorTileState extends State<BlockEditorTile> {
  late final TextEditingController _text;
  late final FocusNode _focus;
  late String _type;

  static const _supportedTypes = <String>{
    'paragraph',
    'heading_1',
    'todo',
    'bulleted_list',
    'quote',
    'code',
  };

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.block.textContent);
    _focus = FocusNode()..addListener(_handleFocusChanged);
    _type = _supportedTypes.contains(widget.block.type)
        ? widget.block.type
        : 'paragraph';
  }

  @override
  void didUpdateWidget(covariant BlockEditorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.textContent != widget.block.textContent) {
      _text.text = widget.block.textContent;
      _type = _supportedTypes.contains(widget.block.type)
          ? widget.block.type
          : 'paragraph';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_handleFocusChanged);
    if (_focus.hasFocus) {
      widget.onBlur();
    }
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focus.hasFocus) {
      widget.onFocus();
    } else {
      widget.onBlur();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxLines = _type == 'code' ? 5 : null;
    final style = switch (_type) {
      'heading_1' => const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      'heading_2' => const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      'quote' => const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
      'code' => const TextStyle(fontFamily: 'monospace', fontSize: 14),
      _ => const TextStyle(fontSize: 16),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'paragraph', child: Text('¶')),
                  DropdownMenuItem(value: 'heading_1', child: Text('H1')),
                  DropdownMenuItem(value: 'todo', child: Text('☑')),
                  DropdownMenuItem(value: 'bulleted_list', child: Text('•')),
                  DropdownMenuItem(value: 'quote', child: Text('❝')),
                  DropdownMenuItem(value: 'code', child: Text('</>')),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _type = value);
                  await widget.onChanged(_type, _text.text);
                },
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _text,
                    focusNode: _focus,
                    enabled: widget.canEdit,
                    maxLines: maxLines,
                    minLines: _type == 'code' ? 3 : 1,
                    style: style,
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: 'Viết gì đó...'),
                    onChanged: widget.onDraft,
                    onSubmitted: (value) => widget.onChanged(_type, value),
                    onEditingComplete: () =>
                        widget.onChanged(_type, _text.text),
                  ),
                  if (widget.leaseLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 6),
                      child: Text(widget.leaseLabel!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ),
                ],
              ),
            ),
            IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
