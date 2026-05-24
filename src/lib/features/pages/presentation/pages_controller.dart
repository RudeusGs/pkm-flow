import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../../../core/utils/session_id.dart';
import '../../../core/utils/json_utils.dart';
import '../data/page_repository.dart';
import '../domain/block_item.dart';
import '../domain/page_item.dart';

class PagesController extends ChangeNotifier {
  PagesController(
      {required PageRepository repository, required RealtimeService realtime})
      : _repository = repository,
        _realtime = realtime;

  final PageRepository _repository;
  final RealtimeService _realtime;
  final String editorSessionId = newEditorSessionId();
  final List<VoidCallback> _unsubscribe = [];
  Timer? _pageHeartbeat;
  Timer? _leaseRenewal;
  Timer? _debounce;

  String? workspaceId;
  String keyword = '';
  PageItem? selectedPage;
  List<PageItem> pages = const [];
  List<BlockItem> blocks = const [];
  Map<String, BlockLease> leases = const {};
  int currentRevision = 0;
  int _draftSequence = 0;
  bool isLoading = false;
  String? error;

  Future<void> loadPages(String nextWorkspaceId, {String? keyword}) async {
    if (workspaceId != nextWorkspaceId) {
      selectedPage = null;
      blocks = const [];
      currentRevision = 0;
      leases = const {};
    }
    workspaceId = nextWorkspaceId;
    this.keyword = keyword ?? this.keyword;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      pages = await _repository.pages(nextWorkspaceId, keyword: this.keyword);
      selectedPage ??= pages.isEmpty ? null : pages.first;
      _bindRealtime();
      if (selectedPage != null) await loadDocument(selectedPage!);
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createPage(String title) async {
    final id = workspaceId;
    if (id == null) {
      return;
    }
    final page = await _repository.createPage(id, title: title, icon: '📝');
    pages = [page, ...pages];
    await loadDocument(page);
  }

  Future<void> renamePage(PageItem page, String title, {String? icon}) async {
    final updated =
        await _repository.updatePage(page, title: title, icon: icon);
    pages =
        pages.map((item) => item.id == updated.id ? updated : item).toList();
    if (selectedPage?.id == updated.id) {
      selectedPage = updated;
    }
    notifyListeners();
  }

  Future<void> duplicatePage(PageItem page) async {
    final created = await _repository.duplicatePage(page.id);
    pages = [created, ...pages];
    notifyListeners();
  }

  Future<void> deletePage(PageItem page) async {
    await _repository.deletePage(page.id);
    pages = pages.where((item) => item.id != page.id).toList();
    if (selectedPage?.id == page.id) {
      await _realtime.leavePage(page.id);
      selectedPage = pages.isEmpty ? null : pages.first;
      blocks = const [];
      currentRevision = 0;
      if (selectedPage != null) await loadDocument(selectedPage!);
    }
    notifyListeners();
  }

  Future<void> loadDocument(PageItem page) async {
    if (selectedPage?.id != page.id && selectedPage != null) {
      await _realtime.leavePage(selectedPage!.id);
    }
    selectedPage = page;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _realtime.joinPage(page.id);
      _startPageHeartbeat(page.id);
      final doc = await _repository.document(page.id);
      currentRevision = doc.currentRevision;
      blocks = doc.blocks;
      leases = const {};
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBlock(String type) async {
    final page = selectedPage;
    if (page == null) {
      return;
    }
    final last = blocks.isEmpty ? null : blocks.last.id;
    final mutation = await _repository.createBlock(
      page.id,
      expectedRevision: currentRevision,
      type: type,
      textContent: type.startsWith('heading') ? 'Tiêu đề mới' : '',
      previousBlockId: last,
    );
    currentRevision = mutation.appliedRevision;
    if (mutation.block != null) blocks = [...blocks, mutation.block!];
    notifyListeners();
  }

  Future<void> updateBlock(BlockItem block, String type, String text) async {
    if (!await acquireLease(block)) {
      return;
    }
    final mutation = await _repository.updateBlock(block,
        expectedRevision: currentRevision,
        editorSessionId: editorSessionId,
        textContent: text,
        type: type);
    currentRevision = mutation.appliedRevision;
    if (mutation.block != null) {
      blocks = blocks
          .map((item) => item.id == block.id ? mutation.block! : item)
          .toList();
    }
    await releaseLease(block);
    notifyListeners();
  }

  Future<void> deleteBlock(BlockItem block) async {
    if (!await acquireLease(block)) {
      return;
    }
    final mutation = await _repository.deleteBlock(block,
        expectedRevision: currentRevision, editorSessionId: editorSessionId);
    currentRevision = mutation.appliedRevision;
    blocks = blocks.where((item) => item.id != block.id).toList();
    leases = Map<String, BlockLease>.from(leases)..remove(block.id);
    notifyListeners();
  }

  Future<void> sendDraft(BlockItem block, String text) async {
    final page = selectedPage;
    if (page == null) {
      return;
    }
    if (!await acquireLease(block)) {
      return;
    }
    _draftSequence += 1;
    await _realtime.sendBlockDraft(
      pageId: page.id,
      blockId: block.id,
      editorSessionId: editorSessionId,
      baseRevision: currentRevision,
      clientSequence: _draftSequence,
      textContent: text,
      type: block.type,
      propsJson: block.propsJson,
    );
  }

  Future<bool> acquireLease(BlockItem block) async {
    final existing = leases[block.id];
    if (existing?.canEdit == true) {
      return true;
    }
    try {
      final lease = await _repository.acquireBlockLease(block,
          editorSessionId: editorSessionId);
      leases = Map<String, BlockLease>.from(leases)..[block.id] = lease;
      _startLeaseRenewal();
      notifyListeners();
      final page = selectedPage;
      if (lease.canEdit && page != null) {
        await _realtime.sendBlockEditingState(
          pageId: page.id,
          blockId: block.id,
          editorSessionId: editorSessionId,
          isEditing: true,
        );
      } else {
        error = lease.holderDisplayName == null
            ? 'Block đang được người khác chỉnh sửa.'
            : '${lease.holderDisplayName} đang sửa block này.';
        notifyListeners();
      }
      return lease.canEdit;
    } catch (err) {
      error = err.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> releaseLease(BlockItem block) async {
    final existing = leases[block.id];
    if (existing?.isHeldByCurrentUser != true) {
      return;
    }
    try {
      await _repository.releaseBlockLease(block,
          editorSessionId: editorSessionId);
      final page = selectedPage;
      if (page != null) {
        await _realtime.sendBlockEditingState(
          pageId: page.id,
          blockId: block.id,
          editorSessionId: editorSessionId,
          isEditing: false,
        );
      }
    } catch (_) {
    } finally {
      leases = Map<String, BlockLease>.from(leases)..remove(block.id);
      _stopLeaseRenewalIfIdle();
      notifyListeners();
    }
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;
    for (final event in ['PageCreated', 'PageUpdated', 'PageDeleted']) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final id = workspaceId;
        if (id != null &&
            (payload.workspaceId == null || payload.workspaceId == id)) {
          _debounced(() => loadPages(id));
        }
      }));
    }
    for (final event in ['BlockCreated', 'BlockUpdated', 'BlockDeleted']) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final page = selectedPage;
        if (page != null &&
            (payload.pageId == null || payload.pageId == page.id)) {
          _debounced(() => loadDocument(page));
        }
      }));
    }
    _unsubscribe.add(_realtime.on('BlockDraftChanged', (event) {
      final page = selectedPage;
      if (page == null || (event.pageId != null && event.pageId != page.id)) {
        return;
      }
      final payload = event.payloadMap;
      final blockId = asString(payload['blockId']);
      final text = payload['textContent']?.toString();
      if (blockId.isEmpty || text == null) {
        return;
      }
      blocks = blocks
          .map((item) => item.id == blockId
              ? item.copyWith(
                  textContent: text, type: payload['type']?.toString())
              : item)
          .toList();
      notifyListeners();
    }));
    _unsubscribe
        .add(_realtime.on('PagePresenceChanged', (_) => notifyListeners()));
  }

  void _debounced(Future<void> Function() action) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => action());
  }

  void _startPageHeartbeat(String pageId) {
    _pageHeartbeat?.cancel();
    _pageHeartbeat = Timer.periodic(
        const Duration(seconds: 25), (_) => _realtime.heartbeatPage(pageId));
  }

  void _startLeaseRenewal() {
    _leaseRenewal ??= Timer.periodic(const Duration(seconds: 30), (_) async {
      final heldBlocks = blocks
          .where((block) => leases[block.id]?.isHeldByCurrentUser == true)
          .toList();
      for (final block in heldBlocks) {
        try {
          final lease = await _repository.renewBlockLease(block,
              editorSessionId: editorSessionId);
          leases = Map<String, BlockLease>.from(leases)..[block.id] = lease;
        } catch (_) {}
      }
      _stopLeaseRenewalIfIdle();
      notifyListeners();
    });
  }

  void _stopLeaseRenewalIfIdle() {
    if (leases.values.any((lease) => lease.isHeldByCurrentUser)) {
      return;
    }
    _leaseRenewal?.cancel();
    _leaseRenewal = null;
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    _pageHeartbeat?.cancel();
    _leaseRenewal?.cancel();
    if (selectedPage != null) {
      _realtime.leavePage(selectedPage!.id);
    }
    super.dispose();
  }
}
