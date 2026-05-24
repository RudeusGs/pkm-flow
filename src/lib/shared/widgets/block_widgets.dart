import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'empty_state.dart';
import 'notion_widgets.dart';

class BlockTypeDefinition {
  const BlockTypeDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.group,
  });

  final String type;
  final String title;
  final String description;
  final IconData icon;
  final String group;
}

const notionBlockTypes = <BlockTypeDefinition>[
  BlockTypeDefinition(
    type: 'paragraph',
    title: 'Text / Paragraph',
    description: 'Simple body text.',
    icon: Icons.notes_rounded,
    group: 'Basic',
  ),
  BlockTypeDefinition(
    type: 'heading_1',
    title: 'Heading 1',
    description: 'Large section title.',
    icon: Icons.title_rounded,
    group: 'Basic',
  ),
  BlockTypeDefinition(
    type: 'heading_2',
    title: 'Heading 2',
    description: 'Medium section title.',
    icon: Icons.text_fields_rounded,
    group: 'Basic',
  ),
  BlockTypeDefinition(
    type: 'heading_3',
    title: 'Heading 3',
    description: 'Small section title.',
    icon: Icons.short_text_rounded,
    group: 'Basic',
  ),
  BlockTypeDefinition(
    type: 'todo',
    title: 'Todo',
    description: 'A checkable task line.',
    icon: Icons.check_box_outlined,
    group: 'Lists',
  ),
  BlockTypeDefinition(
    type: 'bulleted_list',
    title: 'Bullet list',
    description: 'A simple unordered list.',
    icon: Icons.format_list_bulleted_rounded,
    group: 'Lists',
  ),
  BlockTypeDefinition(
    type: 'numbered_list',
    title: 'Numbered list',
    description: 'A list with ordered steps.',
    icon: Icons.format_list_numbered_rounded,
    group: 'Lists',
  ),
  BlockTypeDefinition(
    type: 'quote',
    title: 'Quote',
    description: 'Highlight a note or idea.',
    icon: Icons.format_quote_rounded,
    group: 'Basic',
  ),
  BlockTypeDefinition(
    type: 'code',
    title: 'Code',
    description: 'A monospaced code block.',
    icon: Icons.code_rounded,
    group: 'Advanced',
  ),
  BlockTypeDefinition(
    type: 'image',
    title: 'Image',
    description: 'Paste an image URL.',
    icon: Icons.image_outlined,
    group: 'Media',
  ),
  BlockTypeDefinition(
    type: 'divider',
    title: 'Divider',
    description: 'Separate sections quietly.',
    icon: Icons.horizontal_rule_rounded,
    group: 'Basic',
  ),
  BlockTypeDefinition(
    type: 'table',
    title: 'Table',
    description: 'Rows and columns for structured notes.',
    icon: Icons.table_chart_outlined,
    group: 'Advanced',
  ),
];

class BlockPickerSheet extends StatefulWidget {
  const BlockPickerSheet({super.key});

  @override
  State<BlockPickerSheet> createState() => _BlockPickerSheetState();
}

class _BlockPickerSheetState extends State<BlockPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = notionBlockTypes.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.group.toLowerCase().contains(query);
    }).toList();

    final groups = <String, List<BlockTypeDefinition>>{};
    for (final item in filtered) {
      groups.putIfAbsent(item.group, () => <BlockTypeDefinition>[]).add(item);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .48,
      maxChildSize: .94,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: BottomSheetHeader(
                title: 'Add block',
                subtitle: 'Search or choose a block type.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: NotionTextField(
                controller: _search,
                autofocus: true,
                hintText: 'Search blocks...',
                prefixIcon: Icons.search_rounded,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No block found',
                      message: 'Try text, list, image, or table.',
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        for (final group in const [
                          'Basic',
                          'Lists',
                          'Media',
                          'Advanced'
                        ])
                          if (groups[group]?.isNotEmpty == true) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                group,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            ...groups[group]!.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BlockTypeTile(
                                  item: item,
                                  onTap: () =>
                                      Navigator.pop(context, item.type),
                                ),
                              ),
                            ),
                          ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class BlockTypeTile extends StatelessWidget {
  const BlockTypeTile({super.key, required this.item, required this.onTap});

  final BlockTypeDefinition item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(item.icon, size: 21, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BlockActionSheet extends StatelessWidget {
  const BlockActionSheet({
    super.key,
    required this.hasContent,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  final bool hasContent;
  final bool canMoveUp;
  final bool canMoveDown;

  static Future<String?> show({
    required BuildContext context,
    required bool hasContent,
    required bool canMoveUp,
    required bool canMoveDown,
  }) {
    return NotionBottomSheet.show<String>(
      context: context,
      title: 'Block',
      subtitle: 'Change, duplicate, or remove this block.',
      child: BlockActionSheet(
        hasContent: hasContent,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotionActionRow(
          icon: Icons.transform_rounded,
          title: 'Change block type',
          onTap: () => Navigator.pop(context, 'change_type'),
        ),
        NotionActionRow(
          icon: Icons.content_copy_rounded,
          title: 'Duplicate',
          onTap: () => Navigator.pop(context, 'duplicate'),
        ),
        NotionActionRow(
          icon: Icons.arrow_upward_rounded,
          title: 'Move up',
          subtitle: canMoveUp ? null : 'Not available here.',
          enabled: canMoveUp,
          onTap: () => Navigator.pop(context, 'move_up'),
        ),
        NotionActionRow(
          icon: Icons.arrow_downward_rounded,
          title: 'Move down',
          subtitle: canMoveDown ? null : 'Not available here.',
          enabled: canMoveDown,
          onTap: () => Navigator.pop(context, 'move_down'),
        ),
        const Divider(height: 18),
        NotionActionRow(
          icon: Icons.delete_outline_rounded,
          title: 'Delete',
          subtitle: hasContent ? 'Needs confirmation.' : null,
          danger: true,
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      ],
    );
  }
}

class TableBlockView extends StatefulWidget {
  const TableBlockView({
    super.key,
    required this.propsJson,
    required this.onChanged,
  });

  final String? propsJson;
  final ValueChanged<String> onChanged;

  @override
  State<TableBlockView> createState() => _TableBlockViewState();
}

class _TableBlockViewState extends State<TableBlockView> {
  Timer? _commitTimer;

  @override
  void dispose() {
    _commitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _TableData.fromJson(widget.propsJson);
    if (data.rows.isEmpty || data.columnCount == 0) {
      return NotionCard(
        child: EmptyState(
          icon: Icons.table_chart_outlined,
          title: 'Start with a simple table',
          message: 'Use two columns and two rows, then edit each cell.',
          action: NotionButton(
            label: 'Create 2 x 2 table',
            icon: Icons.add_rounded,
            onPressed: () => _commit(
              _TableData(
                rows: const [
                  ['Name', 'Status'],
                  ['', ''],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var row = 0; row < data.rows.length; row++)
                    Row(
                      children: [
                        for (var column = 0;
                            column < data.columnCount;
                            column++)
                          _TableCell(
                            key: ValueKey('table-cell-$row-$column'),
                            value: data.valueAt(row, column),
                            isHeader: row == 0,
                            onChanged: (value) =>
                                _updateCell(data, row, column, value),
                            onMenu: () => _showCellMenu(data, row, column),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _commit(data.addRow(data.rows.length)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Row'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _commit(data.addColumn(data.columnCount)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Column'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              tooltip: 'Table actions',
              onPressed: () => _showTableMenu(data),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
      ],
    );
  }

  void _updateCell(_TableData data, int row, int column, String value) {
    final next = data.setCell(row, column, value);
    _commitTimer?.cancel();
    _commitTimer =
        Timer(const Duration(milliseconds: 650), () => _commit(next));
  }

  Future<void> _showCellMenu(_TableData data, int row, int column) async {
    final action = await _tableActionSheet(context, title: 'Cell actions');
    if (action == null) return;
    _applyTableAction(data, action, row, column);
  }

  Future<void> _showTableMenu(_TableData data) async {
    final action = await _tableActionSheet(context, title: 'Table actions');
    if (action == null) return;
    _applyTableAction(data, action, data.rows.length - 1, data.columnCount - 1);
  }

  Future<String?> _tableActionSheet(BuildContext context,
      {required String title}) {
    return NotionBottomSheet.show<String>(
      context: context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotionActionRow(
            icon: Icons.keyboard_arrow_up_rounded,
            title: 'Add row above',
            onTap: () => Navigator.pop(context, 'row_above'),
          ),
          NotionActionRow(
            icon: Icons.keyboard_arrow_down_rounded,
            title: 'Add row below',
            onTap: () => Navigator.pop(context, 'row_below'),
          ),
          NotionActionRow(
            icon: Icons.keyboard_arrow_left_rounded,
            title: 'Add column left',
            onTap: () => Navigator.pop(context, 'column_left'),
          ),
          NotionActionRow(
            icon: Icons.keyboard_arrow_right_rounded,
            title: 'Add column right',
            onTap: () => Navigator.pop(context, 'column_right'),
          ),
          const Divider(height: 18),
          NotionActionRow(
            icon: Icons.table_rows_rounded,
            title: 'Delete row',
            danger: true,
            onTap: () => Navigator.pop(context, 'delete_row'),
          ),
          NotionActionRow(
            icon: Icons.view_column_outlined,
            title: 'Delete column',
            danger: true,
            onTap: () => Navigator.pop(context, 'delete_column'),
          ),
          NotionActionRow(
            icon: Icons.layers_clear_outlined,
            title: 'Clear table',
            danger: true,
            onTap: () => Navigator.pop(context, 'clear'),
          ),
        ],
      ),
    );
  }

  void _applyTableAction(_TableData data, String action, int row, int column) {
    final next = switch (action) {
      'row_above' => data.addRow(row),
      'row_below' => data.addRow(row + 1),
      'column_left' => data.addColumn(column),
      'column_right' => data.addColumn(column + 1),
      'delete_row' => data.deleteRow(row),
      'delete_column' => data.deleteColumn(column),
      'clear' => const _TableData(rows: []),
      _ => data,
    };
    _commit(next);
  }

  void _commit(_TableData data) {
    _commitTimer?.cancel();
    widget.onChanged(data.toJson());
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    super.key,
    required this.value,
    required this.isHeader,
    required this.onChanged,
    required this.onMenu,
  });

  final String value;
  final bool isHeader;
  final ValueChanged<String> onChanged;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onMenu,
      child: Container(
        width: 142,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: isHeader ? AppColors.hover : AppColors.surface,
          border: const Border(
            right: BorderSide(color: AppColors.line),
            bottom: BorderSide(color: AppColors.line),
          ),
        ),
        child: TextFormField(
          initialValue: value,
          minLines: 1,
          maxLines: 4,
          onChanged: onChanged,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600,
            height: 1.25,
          ),
          decoration: InputDecoration(
            hintText: isHeader ? 'Header' : 'Cell',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
        ),
      ),
    );
  }
}

class _TableData {
  const _TableData({required this.rows});

  final List<List<String>> rows;

  int get columnCount {
    var count = 0;
    for (final row in rows) {
      if (row.length > count) count = row.length;
    }
    return count;
  }

  String valueAt(int row, int column) {
    if (row < 0 || row >= rows.length) return '';
    if (column < 0 || column >= rows[row].length) return '';
    return rows[row][column];
  }

  _TableData setCell(int row, int column, String value) {
    final next = _normalizedRows();
    next[row][column] = value;
    return _TableData(rows: next);
  }

  _TableData addRow(int index) {
    final next = _normalizedRows();
    final safeIndex = index.clamp(0, next.length).toInt();
    next.insert(
        safeIndex, List<String>.filled(columnCount == 0 ? 2 : columnCount, ''));
    return _TableData(rows: next);
  }

  _TableData addColumn(int index) {
    final next = _normalizedRows();
    final safeIndex = index.clamp(0, columnCount).toInt();
    if (next.isEmpty) {
      return const _TableData(rows: [
        ['Name', 'Status'],
        ['', ''],
      ]);
    }
    for (final row in next) {
      row.insert(safeIndex, '');
    }
    return _TableData(rows: next);
  }

  _TableData deleteRow(int index) {
    final next = _normalizedRows();
    if (next.length <= 1 || index < 0 || index >= next.length) return this;
    next.removeAt(index);
    return _TableData(rows: next);
  }

  _TableData deleteColumn(int index) {
    final next = _normalizedRows();
    if (columnCount <= 1 || index < 0 || index >= columnCount) return this;
    for (final row in next) {
      if (index < row.length) row.removeAt(index);
    }
    return _TableData(rows: next);
  }

  List<List<String>> _normalizedRows() {
    final count = columnCount == 0 ? 2 : columnCount;
    return rows.map((row) {
      final next = List<String>.from(row);
      while (next.length < count) {
        next.add('');
      }
      return next;
    }).toList();
  }

  String toJson() => jsonEncode({
        'rows': rows,
        'hasHeader': true,
      });

  static _TableData fromJson(String? json) {
    if (json == null || json.trim().isEmpty) return const _TableData(rows: []);
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        final rows = decoded['rows'];
        if (rows is List) {
          return _TableData(
            rows: rows
                .map((row) {
                  if (row is List)
                    return row.map((cell) => cell?.toString() ?? '').toList();
                  return <String>[];
                })
                .where((row) => row.isNotEmpty)
                .toList(),
          );
        }
      }
      if (decoded is List) {
        return _TableData(
          rows: decoded
              .map((row) {
                if (row is List)
                  return row.map((cell) => cell?.toString() ?? '').toList();
                return <String>[];
              })
              .where((row) => row.isNotEmpty)
              .toList(),
        );
      }
    } catch (_) {
      return const _TableData(rows: []);
    }
    return const _TableData(rows: []);
  }
}
