import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notion_widgets.dart';
import '../../pages/domain/page_item.dart';
import '../../pages/presentation/editor_page.dart';
import '../../pages/presentation/pages_controller.dart';
import '../domain/workspace.dart';
import 'workspace_controller.dart';

class WorkspaceHubPage extends StatefulWidget {
  const WorkspaceHubPage({super.key, required this.workspaceController});

  final WorkspaceController workspaceController;

  @override
  State<WorkspaceHubPage> createState() => _WorkspaceHubPageState();
}

class _WorkspaceHubPageState extends State<WorkspaceHubPage> {
  late final PagesController _pages;
  final _search = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final deps = AppScope.read(context);
    _pages = PagesController(
        repository: deps.pageRepository, realtime: deps.realtime);
    _loadPages();
    widget.workspaceController.addListener(_onWorkspaceChanged);
  }

  @override
  void dispose() {
    widget.workspaceController.removeListener(_onWorkspaceChanged);
    _searchDebounce?.cancel();
    _search.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onWorkspaceChanged() => _loadPages();

  void _loadPages({String? keyword}) {
    final workspace = widget.workspaceController.selected;
    if (workspace != null) {
      _pages.loadPages(workspace.id, keyword: keyword ?? _search.text);
    }
  }

  void _loadTrash() {
    final workspace = widget.workspaceController.selected;
    if (workspace != null) {
      _pages.loadTrash(workspace.id);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
        const Duration(milliseconds: 320), () => _loadPages(keyword: value));
  }

  void _toggleTrashView() {
    _searchDebounce?.cancel();
    _search.clear();
    setState(() {});
    if (_pages.isTrashView) {
      _loadPages(keyword: '');
    } else {
      _loadTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.workspaceController, _pages]),
      builder: (context, _) {
        final workspace = widget.workspaceController.selected;
        if (widget.workspaceController.isLoading &&
            widget.workspaceController.workspaces.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (workspace == null) {
          return _NoWorkspaceState(
              onCreate: () => _showCreateWorkspace(context));
        }

        return RefreshIndicator(
          onRefresh: () async {
            await widget.workspaceController.load();
            if (_pages.isTrashView) {
              _loadTrash();
            } else {
              _loadPages();
            }
          },
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _WorkspaceHeader(
                  workspace: workspace,
                  pageCount: _pages.pages.length,
                  onSwitch: () => _showWorkspaceSwitcher(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Column(
                    children: [
                      if (!_pages.isTrashView) ...[
                        NotionTextField(
                          controller: _search,
                          hintText: 'Search pages...',
                          prefixIcon: Icons.search_rounded,
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _search.clear();
                                    _loadPages(keyword: '');
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          onChanged: (value) {
                            setState(() {});
                            _onSearchChanged(value);
                          },
                          onSubmitted: (value) => _loadPages(keyword: value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          if (!_pages.isTrashView) ...[
                            Expanded(
                              child: NotionButton(
                                label: 'Create page',
                                icon: Icons.note_add_outlined,
                                expanded: true,
                                onPressed: () => _showCreatePage(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: NotionButton(
                              label: _pages.isTrashView
                                  ? 'Back to pages'
                                  : 'Trash',
                              icon: _pages.isTrashView
                                  ? Icons.description_outlined
                                  : Icons.delete_outline_rounded,
                              secondary: !_pages.isTrashView,
                              expanded: true,
                              onPressed: _toggleTrashView,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                sliver: _buildPageList(workspace),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageList(Workspace workspace) {
    if (_pages.isLoading && _pages.pages.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pages.pages.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.description_outlined,
          title: _search.text.trim().isEmpty
              ? (_pages.isTrashView ? 'Trash is empty' : 'No pages yet')
              : 'No matching pages',
          message: _search.text.trim().isEmpty
              ? (_pages.isTrashView
                  ? 'Deleted pages will show up here so you can restore them.'
                  : 'Create a first page for notes, plans, or anything you want to remember.')
              : 'Try a shorter search or create a new page.',
          action: _pages.isTrashView
              ? NotionButton(
                  label: 'Back to pages',
                  icon: Icons.description_outlined,
                  onPressed: _toggleTrashView,
                )
              : NotionButton(
                  label: 'Create page',
                  icon: Icons.add_rounded,
                  onPressed: () => _showCreatePage(context),
                ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rawIndex) {
          if (rawIndex.isOdd) return const SizedBox(height: 8);
          final index = rawIndex ~/ 2;
          final page = _pages.pages[index];
          return _PageTreeTile(
            page: page,
            onTap: () => _openPage(page),
            onMore: () => _showPageActions(page),
          );
        },
        childCount: _pages.pages.length * 2 - 1,
      ),
    );
  }

  Future<void> _openPage(PageItem page) {
    return Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => EditorPage(controller: _pages, page: page)),
    );
  }

  Future<void> _showCreateWorkspace(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    var visibility = 'private';
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BottomSheetHeader(
                title: 'Create workspace',
                subtitle:
                    'A workspace keeps pages, tasks, members, and sharing together.',
              ),
              NotionTextField(
                  controller: name,
                  autofocus: true,
                  labelText: 'Workspace name'),
              const SizedBox(height: 10),
              NotionTextField(
                controller: description,
                labelText: 'Description',
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NotionPill(
                    label: 'Private',
                    icon: Icons.lock_outline_rounded,
                    selected: visibility == 'private',
                    onTap: () => setSheetState(() => visibility = 'private'),
                  ),
                  NotionPill(
                    label: 'Public',
                    icon: Icons.public_rounded,
                    selected: visibility == 'public',
                    onTap: () => setSheetState(() => visibility = 'public'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              NotionButton(
                label: 'Create workspace',
                icon: Icons.add_rounded,
                expanded: true,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (created == true && name.text.trim().isNotEmpty) {
      await widget.workspaceController.create(
        name.text.trim(),
        description: description.text.trim(),
        visibility: visibility,
      );
    }
  }

  Future<void> _showCreatePage(BuildContext context) async {
    final input = TextEditingController();
    final icon = TextEditingController(text: '📝');
    final title = await showModalBottomSheet<String>(
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
              title: 'New page',
              subtitle: 'Give it a simple name. You can change it later.',
            ),
            Row(
              children: [
                SizedBox(
                  width: 78,
                  child: NotionTextField(
                    controller: icon,
                    labelText: 'Icon',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NotionTextField(
                    controller: input,
                    autofocus: true,
                    labelText: 'Page title',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) =>
                        Navigator.pop(context, value.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            NotionButton(
              label: 'Create page',
              icon: Icons.add_rounded,
              expanded: true,
              onPressed: () => Navigator.pop(context, input.text.trim()),
            ),
          ],
        ),
      ),
    );

    if (title != null && title.trim().isNotEmpty) {
      final created = await _pages.createPage(
        title.trim(),
        icon: icon.text.trim().isEmpty ? '📝' : icon.text.trim(),
      );
      if (!mounted || created == null) return;
      await _openPage(created);
    }
  }

  Future<void> _showWorkspaceSwitcher(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .4,
        maxChildSize: .9,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: BottomSheetHeader(
                title: 'Switch workspace',
                subtitle: 'Pick a space or create a new one.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: NotionButton(
                label: 'Create workspace',
                icon: Icons.add_rounded,
                expanded: true,
                onPressed: () {
                  Navigator.pop(context);
                  _showCreateWorkspace(context);
                },
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                itemCount: widget.workspaceController.workspaces.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final workspace =
                      widget.workspaceController.workspaces[index];
                  final selected =
                      widget.workspaceController.selected?.id == workspace.id;
                  return NotionListTile(
                    onTap: () async {
                      Navigator.pop(context);
                      await widget.workspaceController.select(workspace);
                    },
                    leading: _WorkspaceIcon(
                        name: workspace.name, selected: selected),
                    title: workspace.name,
                    subtitle: workspace.description?.isNotEmpty == true
                        ? workspace.description!
                        : '${workspace.visibility} · ${workspace.currentUserRole}',
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.ink)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPageActions(PageItem page) async {
    final action = await NotionBottomSheet.show<String>(
      context: context,
      title: page.title,
      subtitle: 'Page actions',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotionActionRow(
            icon: Icons.open_in_new_rounded,
            title: 'Open',
            enabled: !page.isArchived,
            onTap: () => Navigator.pop(context, 'open'),
          ),
          NotionActionRow(
            icon: Icons.drive_file_rename_outline_rounded,
            title: 'Rename',
            enabled: !page.isArchived,
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          if (!page.isArchived)
            NotionActionRow(
              icon: page.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              title: page.isFavorite ? 'Remove favorite' : 'Add favorite',
              onTap: () => Navigator.pop(
                context,
                page.isFavorite ? 'unfavorite' : 'favorite',
              ),
            ),
          NotionActionRow(
            icon: Icons.content_copy_rounded,
            title: 'Duplicate',
            subtitle: 'Create a copy of this page.',
            enabled: !page.isArchived,
            onTap: () => Navigator.pop(context, 'duplicate'),
          ),
          if (!page.isArchived) ...[
            const NotionActionRow(
              icon: Icons.folder_open_rounded,
              title: 'Move',
              subtitle: 'Move page is not wired on mobile yet.',
              enabled: false,
            ),
            const NotionActionRow(
              icon: Icons.ios_share_rounded,
              title: 'Share',
              subtitle: 'Workspace sharing is available from the top menu.',
              enabled: false,
            ),
          ],
          const Divider(height: 18),
          if (page.isArchived)
            NotionActionRow(
              icon: Icons.restore_rounded,
              title: 'Restore page',
              subtitle: 'Move this page back to the active page list.',
              onTap: () => Navigator.pop(context, 'restore'),
            )
          else
            NotionActionRow(
              icon: Icons.delete_outline_rounded,
              title: 'Move to trash',
              subtitle: 'This page will move to trash and can be restored.',
              danger: true,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
        ],
      ),
    );

    if (action == 'open') {
      await _openPage(page);
    } else if (action == 'rename') {
      await _showRenamePage(page);
    } else if (action == 'duplicate') {
      final duplicated = await _pages.duplicatePage(page);
      if (!mounted || duplicated == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated "${page.title}".')),
      );
    } else if (action == 'favorite') {
      final saved = await _pages.favoritePage(page);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? 'Added "${page.title}" to favorites.'
              : _pages.error ?? 'Could not update favorite.'),
        ),
      );
    } else if (action == 'unfavorite') {
      final saved = await _pages.unfavoritePage(page);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? 'Removed "${page.title}" from favorites.'
              : _pages.error ?? 'Could not update favorite.'),
        ),
      );
    } else if (action == 'restore') {
      final restored = await _pages.restorePage(page);
      if (!mounted || restored == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored "${page.title}".')),
      );
    } else if (action == 'delete') {
      if (!mounted) return;
      final confirmed = await NotionConfirmDialog.show(
        context: context,
        title: 'Move page to trash?',
        message: 'You can restore it later from Trash.',
        confirmLabel: 'Move',
        danger: true,
      );

      if (!confirmed) return;
      final deleted = await _pages.deletePage(page);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleted
              ? 'Moved "${page.title}" to trash.'
              : _pages.error ?? 'Could not move page to trash.'),
        ),
      );
    }
  }

  Future<void> _showRenamePage(PageItem page) async {
    final title = TextEditingController(text: page.title);
    final icon = TextEditingController(text: page.icon ?? '📄');
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
            const BottomSheetHeader(title: 'Rename page'),
            Row(
              children: [
                SizedBox(
                    width: 78,
                    child:
                        NotionTextField(controller: icon, labelText: 'Icon')),
                const SizedBox(width: 10),
                Expanded(
                    child: NotionTextField(
                        controller: title,
                        autofocus: true,
                        labelText: 'Title')),
              ],
            ),
            const SizedBox(height: 18),
            NotionButton(
              label: 'Save',
              icon: Icons.done_rounded,
              expanded: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _pages.renamePage(
        page,
        title: title.text,
        icon: icon.text.trim().isEmpty ? '📄' : icon.text.trim(),
      );
    }
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.workspace,
    required this.pageCount,
    required this.onSwitch,
  });

  final Workspace workspace;
  final int pageCount;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final description = workspace.description?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WorkspaceIcon(name: workspace.name, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description?.isNotEmpty == true
                          ? description!
                          : '$pageCount pages · ${workspace.currentUserRole.isEmpty ? workspace.visibility : workspace.currentUserRole}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Switch workspace'),
          ),
        ],
      ),
    );
  }
}

class _PageTreeTile extends StatelessWidget {
  const _PageTreeTile({
    required this.page,
    required this.onTap,
    required this.onMore,
  });

  final PageItem page;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final hasParent =
        page.parentPageId != null && page.parentPageId!.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(left: hasParent ? 18 : 0),
      child: NotionCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          minVerticalPadding: 10,
          contentPadding:
              const EdgeInsets.only(left: 14, right: 6, top: 4, bottom: 4),
          leading: SizedBox(
            width: 36,
            child: Center(
              child: Text(
                page.icon?.isNotEmpty == true ? page.icon! : '📄',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          title: Text(
            page.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.ink, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            page.isArchived ? 'Archived' : 'Revision ${page.currentRevision}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted),
          ),
          trailing: IconButton(
            tooltip: 'Page actions',
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceIcon extends StatelessWidget {
  const _WorkspaceIcon({
    required this.name,
    this.selected = false,
    this.size = 44,
  });

  final String name;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? 'W' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(size * .32),
        border: Border.all(color: selected ? AppColors.ink : AppColors.line),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.ink,
            fontSize: size * .42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _NoWorkspaceState extends StatelessWidget {
  const _NoWorkspaceState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.space_dashboard_outlined,
      title: 'No workspace yet',
      message: 'Create a workspace for pages, tasks, members, and sharing.',
      action: NotionButton(
        label: 'Create workspace',
        icon: Icons.add_rounded,
        onPressed: onCreate,
      ),
    );
  }
}
