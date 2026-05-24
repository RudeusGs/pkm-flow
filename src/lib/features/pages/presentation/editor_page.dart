import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_url.dart';
import '../../../shared/widgets/block_widgets.dart';
import '../../../shared/widgets/notion_widgets.dart';
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
  late final TextEditingController _title;
  late final TextEditingController _icon;
  String? _pendingFocusBlockId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.page.title);
    _icon = TextEditingController(text: widget.page.icon ?? '📝');
    widget.controller.loadDocument(widget.page);
  }

  @override
  void dispose() {
    _title.dispose();
    _icon.dispose();
    super.dispose();
  }

  Future<void> _saveTitle() async {
    await widget.controller.updatePageTitle(
      _title.text,
      icon: _icon.text.trim().isEmpty ? '📝' : _icon.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final page = widget.controller.selectedPage ?? widget.page;
        return NotionScaffold(
          appBar: AppBar(
            title:
                Text(page.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Save title',
                onPressed: _saveTitle,
                icon: const Icon(Icons.done_rounded),
              ),
              IconButton(
                tooltip: 'Add block',
                onPressed: () => _showAddBlock(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'editor-add-block',
            tooltip: 'Add block',
            onPressed: () => _showAddBlock(context),
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.background,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.add_rounded),
          ),
          body: widget.controller.isLoading && widget.controller.blocks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                  itemCount: widget.controller.blocks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _PageHeader(
                          icon: _icon, title: _title, onSave: _saveTitle);
                    }

                    final blockIndex = index - 1;
                    final block = widget.controller.blocks[blockIndex];
                    return BlockEditorTile(
                      block: block,
                      index: blockIndex,
                      totalCount: widget.controller.blocks.length,
                      autofocus: block.id == _pendingFocusBlockId,
                      onAutofocusHandled: () =>
                          setState(() => _pendingFocusBlockId = null),
                      onChanged: (type, text, {propsJson}) =>
                          widget.controller.updateBlock(
                        block,
                        type,
                        text,
                        propsJson: propsJson,
                      ),
                      onDraft: (text) =>
                          widget.controller.sendDraft(block, text),
                      onDuplicate: () async {
                        final duplicated =
                            await widget.controller.duplicateBlock(block);
                        if (duplicated != null && mounted) {
                          setState(() => _pendingFocusBlockId = duplicated.id);
                        }
                      },
                      onDelete: () => widget.controller.deleteBlock(block),
                      onMoveUnsupported: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Moving blocks needs backend ordering support.')),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _showAddBlock(BuildContext context) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const BlockPickerSheet(),
    );
    if (type != null) {
      final block = await widget.controller.addBlock(type);
      if (block != null && mounted)
        setState(() => _pendingFocusBlockId = block.id);
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.icon,
    required this.title,
    required this.onSave,
  });

  final TextEditingController icon;
  final TextEditingController title;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Focus(
        onFocusChange: (focused) {
          if (!focused) onSave();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                controller: icon,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: '📝',
                  contentPadding: EdgeInsets.zero,
                ),
                onEditingComplete: onSave,
              ),
            ),
            TextField(
              controller: title,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 34,
                height: 1.08,
                fontWeight: FontWeight.w900,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'Untitled',
                contentPadding: EdgeInsets.zero,
              ),
              onEditingComplete: onSave,
            ),
          ],
        ),
      ),
    );
  }
}

class BlockEditorTile extends StatefulWidget {
  const BlockEditorTile({
    super.key,
    required this.block,
    required this.index,
    required this.totalCount,
    required this.onChanged,
    required this.onDraft,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUnsupported,
    this.autofocus = false,
    this.onAutofocusHandled,
  });

  final BlockItem block;
  final int index;
  final int totalCount;
  final Future<void> Function(String type, String text, {String? propsJson})
      onChanged;
  final Future<void> Function(String text) onDraft;
  final Future<void> Function() onDuplicate;
  final Future<void> Function() onDelete;
  final VoidCallback onMoveUnsupported;
  final bool autofocus;
  final VoidCallback? onAutofocusHandled;

  @override
  State<BlockEditorTile> createState() => _BlockEditorTileState();
}

class _BlockEditorTileState extends State<BlockEditorTile> {
  late final TextEditingController _text;
  late final FocusNode _focusNode;
  late String _type;
  Timer? _draftTimer;
  bool _saving = false;

  static const _supportedTypes = <String>{
    'paragraph',
    'heading_1',
    'heading_2',
    'heading_3',
    'todo',
    'bulleted_list',
    'numbered_list',
    'quote',
    'code',
    'image',
    'divider',
    'table',
  };

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.block.textContent);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    _type = _normalizeType(widget.block.type);
    if (widget.autofocus) _requestFocus();
  }

  @override
  void didUpdateWidget(covariant BlockEditorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _text.text = widget.block.textContent;
      _type = _normalizeType(widget.block.type);
      if (widget.autofocus) _requestFocus();
      return;
    }

    if (!_focusNode.hasFocus &&
        oldWidget.block.textContent != widget.block.textContent) {
      _text.text = widget.block.textContent;
    }
    if (oldWidget.block.type != widget.block.type) {
      _type = _normalizeType(widget.block.type);
    }
    if (!oldWidget.autofocus && widget.autofocus) _requestFocus();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _text.dispose();
    super.dispose();
  }

  String _normalizeType(String type) =>
      _supportedTypes.contains(type) ? type : 'paragraph';

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      widget.onAutofocusHandled?.call();
    });
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitText();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockHandle(
            type: _type,
            onTap: _showBlockMenu,
          ),
          Expanded(child: _buildBlockBody()),
        ],
      ),
    );
  }

  Widget _buildBlockBody() {
    if (_type == 'divider') {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showBlockMenu,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(),
        ),
      );
    }

    if (_type == 'table') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TableBlockView(
          propsJson: widget.block.propsJson,
          onChanged: (propsJson) =>
              widget.onChanged('table', '', propsJson: propsJson),
        ),
      );
    }

    if (_type == 'image') {
      return _ImageBlockEditor(
        controller: _text,
        focusNode: _focusNode,
        saving: _saving,
        onChanged: _handleTextChanged,
        onCommit: _commitText,
        onClear: () {
          _text.clear();
          _commitText();
        },
      );
    }

    final style = _styleForType(_type);
    final prefix = _prefixForType(_type);
    final isCode = _type == 'code';

    return Container(
      decoration: BoxDecoration(
        color: isCode ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isCode ? Border.all(color: AppColors.line) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix != null)
            SizedBox(
              width: 28,
              child: Padding(
                padding: EdgeInsets.only(top: isCode ? 13 : 11),
                child: Center(
                  child: Text(
                    prefix,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focusNode,
              minLines: isCode ? 4 : 1,
              maxLines: isCode ? 10 : null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: style,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: _hintForType(_type),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: prefix == null ? 0 : 2,
                  vertical: isCode ? 12 : 8,
                ),
              ),
              onChanged: _handleTextChanged,
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 14, right: 4),
              child: SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _styleForType(String type) {
    return switch (type) {
      'heading_1' => const TextStyle(
          color: AppColors.ink,
          fontSize: 25,
          height: 1.15,
          fontWeight: FontWeight.w900,
        ),
      'heading_2' => const TextStyle(
          color: AppColors.ink,
          fontSize: 21,
          height: 1.18,
          fontWeight: FontWeight.w900,
        ),
      'heading_3' => const TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w800,
        ),
      'quote' => const TextStyle(
          color: AppColors.muted,
          fontSize: 16,
          height: 1.35,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      'code' => const TextStyle(
          color: AppColors.ink,
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      _ => const TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          height: 1.42,
          fontWeight: FontWeight.w500,
        ),
    };
  }

  String? _prefixForType(String type) {
    return switch (type) {
      'todo' => '☐',
      'bulleted_list' => '•',
      'numbered_list' => '1.',
      'quote' => '❝',
      _ => null,
    };
  }

  String _hintForType(String type) {
    return switch (type) {
      'heading_1' => 'Heading 1',
      'heading_2' => 'Heading 2',
      'heading_3' => 'Heading 3',
      'todo' => 'To-do',
      'bulleted_list' => 'List item',
      'numbered_list' => 'List item',
      'quote' => 'Quote',
      'code' => 'Code',
      _ => 'Write something...',
    };
  }

  void _handleTextChanged(String value) {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), () {
      widget.onDraft(value);
    });
  }

  Future<void> _commitText() async {
    if (_type == 'table' || _saving) return;
    _draftTimer?.cancel();
    setState(() => _saving = true);
    try {
      await widget.onChanged(_type, _text.text);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showBlockMenu() async {
    final action = await BlockActionSheet.show(
      context: context,
      hasContent: _hasContent,
      canMoveUp: widget.index > 0,
      canMoveDown: widget.index < widget.totalCount - 1,
    );
    if (action == null) return;

    if (action == 'change_type') {
      final type = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const BlockPickerSheet(),
      );
      if (type == null) return;
      setState(() => _type = type);
      await widget.onChanged(_type, _text.text,
          propsJson: _type == 'table' ? widget.block.propsJson : null);
      return;
    }

    if (action == 'duplicate') {
      await widget.onDuplicate();
      return;
    }

    if (action == 'move_up' || action == 'move_down') {
      widget.onMoveUnsupported();
      return;
    }

    if (action == 'delete') {
      if (_hasContent) {
        final confirmed = await NotionConfirmDialog.show(
          context: context,
          title: 'Delete block?',
          message: 'This block has content. Deleting it cannot be undone.',
          confirmLabel: 'Delete',
          danger: true,
        );
        if (!confirmed) return;
      }
      await widget.onDelete();
    }
  }

  bool get _hasContent {
    if (_type == 'divider') return false;
    if (_type == 'table')
      return widget.block.propsJson?.trim().isNotEmpty == true;
    return _text.text.trim().isNotEmpty;
  }
}

class _BlockHandle extends StatelessWidget {
  const _BlockHandle({required this.type, required this.onTap});

  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onTap,
      child: SizedBox(
        width: 34,
        height: 44,
        child: Center(
          child: Icon(_iconForType(type), color: AppColors.subtle, size: 18),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'heading_1' || 'heading_2' || 'heading_3' => Icons.title_rounded,
      'todo' => Icons.check_box_outlined,
      'bulleted_list' => Icons.format_list_bulleted_rounded,
      'numbered_list' => Icons.format_list_numbered_rounded,
      'quote' => Icons.format_quote_rounded,
      'code' => Icons.code_rounded,
      'image' => Icons.image_outlined,
      'divider' => Icons.horizontal_rule_rounded,
      'table' => Icons.table_chart_outlined,
      _ => Icons.drag_indicator_rounded,
    };
  }
}

class _ImageBlockEditor extends StatelessWidget {
  const _ImageBlockEditor({
    required this.controller,
    required this.focusNode,
    required this.saving,
    required this.onChanged,
    required this.onCommit,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool saving;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onCommit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final url = resolveImageUrl(controller.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null && url.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return NotionCard(
                  child: Row(
                    children: const [
                      Icon(Icons.broken_image_outlined, color: AppColors.muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Image preview is unavailable.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Paste image URL',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                onChanged: onChanged,
                onEditingComplete: () {
                  onCommit();
                },
                onSubmitted: (_) {
                  onCommit();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Remove image URL',
              onPressed: controller.text.trim().isEmpty ? null : onClear,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
