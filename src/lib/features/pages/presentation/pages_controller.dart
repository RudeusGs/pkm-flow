import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/session_id.dart';
import '../data/page_repository.dart';
import '../domain/block_item.dart';
import '../domain/page_item.dart';

class PagesController extends ChangeNotifier {
  PagesController({
    required PageRepository repository,
    required RealtimeService realtime,
  })  : _repository = repository,
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
  bool isTrashView = false;
  PageItem? selectedPage;
  List<PageItem> pages = const [];
  List<BlockItem> blocks = const [];
  Map<String, BlockLease> leases = const {};
  int currentRevision = 0;
  int _draftSequence = 0;
  String? activeBlockId;
  bool isLoading = false;
  bool isBusy = false;
  String? error;

  Future<void> loadPages(String nextWorkspaceId, {String? keyword}) async {
    if (workspaceId != nextWorkspaceId) {
      selectedPage = null;
      blocks = const [];
      leases = const {};
      currentRevision = 0;
      activeBlockId = null;
    }

    workspaceId = nextWorkspaceId;
    this.keyword = keyword ?? this.keyword;
    isTrashView = false;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      pages = await _repository.pages(nextWorkspaceId, keyword: this.keyword);
      final currentId = selectedPage?.id;
      selectedPage = _findPage(currentId);
      if (selectedPage == null) {
        blocks = const [];
        leases = const {};
        currentRevision = 0;
        activeBlockId = null;
      }
      _bindRealtime();
    } catch (err) {
      error = _message(err);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  PageItem? _findPage(String? id) {
    if (id == null) return null;
    for (final page in pages) {
      if (page.id == id) return page;
    }
    return null;
  }

  Future<void> loadTrash(String nextWorkspaceId) async {
    if (workspaceId != nextWorkspaceId || !isTrashView) {
      selectedPage = null;
      blocks = const [];
      leases = const {};
      currentRevision = 0;
      activeBlockId = null;
    }

    workspaceId = nextWorkspaceId;
    keyword = '';
    isTrashView = true;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      pages = await _repository.trashPages(nextWorkspaceId);
      _bindRealtime();
    } catch (err) {
      error = _message(err);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PageItem?> createPage(
    String title, {
    String icon = '📝',
    String? parentPageId,
  }) async {
    final id = workspaceId;
    if (id == null) return null;

    isBusy = true;
    error = null;
    notifyListeners();

    try {
      final page = await _repository.createPage(
        id,
        title: title,
        icon: icon,
        parentPageId: parentPageId,
      );

      pages = [page, ...pages];
      selectedPage = page;
      blocks = const [];
      leases = const {};
      currentRevision = page.currentRevision;
      activeBlockId = null;
      return page;
    } catch (err) {
      error = _message(err);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> updatePageTitle(String title, {String? icon}) async {
    final page = selectedPage;
    if (page == null || title.trim().isEmpty) return false;

    return _updatePageMetadata(
      page,
      title: title.trim(),
      icon: icon ?? page.icon,
      coverImage: page.coverImage,
    );
  }

  Future<bool> renamePage(
    PageItem page, {
    required String title,
    String? icon,
  }) async {
    if (title.trim().isEmpty) return false;

    return _updatePageMetadata(
      page,
      title: title.trim(),
      icon: icon ?? page.icon,
      coverImage: page.coverImage,
    );
  }

  Future<bool> updatePageCoverUrl(String coverImage) async {
    final page = selectedPage;
    if (page == null) return false;

    return _updatePageMetadata(
      page,
      title: page.title,
      icon: page.icon,
      coverImage: coverImage.trim(),
    );
  }

  Future<PageItem?> uploadCoverImage({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    final page = selectedPage;
    if (page == null) return null;

    isBusy = true;
    error = null;
    notifyListeners();

    try {
      final updated = await _repository.uploadCoverImage(
        page,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      _replacePage(updated);
      currentRevision = updated.currentRevision;
      return updated;
    } catch (err) {
      if (_isRevisionConflict(err)) {
        await refreshDocument();
      }
      error = _message(err);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> uploadImageFile({
    required List<int> bytes,
    required String fileName,
    String? contentType,
    String purpose = 'page-image',
  }) async {
    if (bytes.isEmpty) return null;

    isBusy = true;
    error = null;
    notifyListeners();

    try {
      final url = await _repository.uploadImageFile(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        purpose: purpose,
      );
      error = null;
      return url.trim().isEmpty ? null : url.trim();
    } catch (err) {
      error = _message(err);
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<PageItem?> duplicatePage(PageItem page) async {
    try {
      final duplicated = await _repository.duplicatePage(page);
      pages = [duplicated, ...pages];
      notifyListeners();
      return duplicated;
    } catch (err) {
      error = _message(err);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deletePage(PageItem page) async {
    try {
      await _repository.deletePage(page);

      pages = pages.where((item) => item.id != page.id).toList();

      if (selectedPage?.id == page.id) {
        selectedPage = pages.isEmpty ? null : pages.first;
        blocks = const [];
        leases = const {};
        currentRevision = 0;
        activeBlockId = null;

        if (selectedPage != null) {
          await loadDocument(selectedPage!);
        }
      }

      notifyListeners();
      return true;
    } catch (err) {
      error = _message(err);
      notifyListeners();
      return false;
    }
  }

  Future<PageItem?> restorePage(PageItem page) async {
    try {
      final restored = await _repository.restorePage(page);
      pages = pages.where((item) => item.id != page.id).toList();

      if (selectedPage?.id == page.id) {
        selectedPage = null;
        blocks = const [];
        leases = const {};
        currentRevision = 0;
        activeBlockId = null;
      }

      notifyListeners();
      return restored;
    } catch (err) {
      error = _message(err);
      notifyListeners();
      return null;
    }
  }

  Future<bool> favoritePage(PageItem page) async {
    try {
      final updated = await _repository.favoritePage(page);
      _replacePage(updated.copyWith(isFavorite: true));
      error = null;
      notifyListeners();
      return true;
    } catch (err) {
      error = _message(err);
      notifyListeners();
      return false;
    }
  }

  Future<bool> unfavoritePage(PageItem page) async {
    try {
      await _repository.unfavoritePage(page);
      _replacePage(page.copyWith(isFavorite: false));
      error = null;
      notifyListeners();
      return true;
    } catch (err) {
      error = _message(err);
      notifyListeners();
      return false;
    }
  }

  Future<bool> _updatePageMetadata(
    PageItem page, {
    required String title,
    String? icon,
    String? coverImage,
    bool retryOnRevisionConflict = true,
  }) async {
    isBusy = true;
    error = null;
    notifyListeners();

    try {
      final latest = selectedPage?.id == page.id ? selectedPage! : page;
      final updated = await _repository.updatePage(
        latest,
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        icon: icon,
        coverImage: coverImage,
      );

      _replacePage(updated);
      currentRevision = updated.currentRevision;
      error = null;
      return true;
    } catch (err) {
      if (retryOnRevisionConflict && _isRevisionConflict(err)) {
        await refreshDocument();
        final refreshed = selectedPage?.id == page.id ? selectedPage! : page;
        return _updatePageMetadata(
          refreshed,
          title: title,
          icon: icon,
          coverImage: coverImage,
          retryOnRevisionConflict: false,
        );
      }

      error = _message(err);
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> loadDocument(PageItem page) async {
    final oldPage = selectedPage;
    if (oldPage != null && oldPage.id != page.id) {
      await _realtime.leavePage(oldPage.id);
      activeBlockId = null;
      leases = const {};
      _stopLeaseRenewalIfIdle();
    }

    selectedPage = page;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _realtime.joinPage(page.id);
      _startPageHeartbeat(page.id);

      final latestPage = await _repository.page(page.id);
      final doc = await _repository.document(page.id);
      currentRevision = doc.currentRevision;
      blocks = _sortBlocks(doc.blocks);
      selectedPage = latestPage.copyWith(currentRevision: currentRevision);
      pages = pages
          .map((item) => item.id == page.id ? selectedPage! : item)
          .toList();
    } catch (err) {
      error = _message(err);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDocument() async {
    final page = selectedPage;
    if (page == null) return;
    await loadDocument(page);
  }

  Future<BlockItem?> addBlock(String type, {BlockItem? afterBlock}) async {
    final page = selectedPage;
    if (page == null) return null;

    final normalizedType = _normalizeType(type);
    final previousId =
        afterBlock?.id ?? (blocks.isEmpty ? null : blocks.last.id);

    try {
      final mutation = await _repository.createBlock(
        page.id,
        expectedRevision: currentRevision,
        type: normalizedType,
        textContent: _defaultTextForType(normalizedType),
        propsJson: _defaultPropsForType(normalizedType),
        previousBlockId: previousId,
      );

      _applyMutation(mutation);
      notifyListeners();
      return mutation.block;
    } catch (err) {
      if (_isRevisionConflict(err)) {
        await refreshDocument();
        return addBlock(type, afterBlock: afterBlock);
      }

      error = _message(err);
      notifyListeners();
      return null;
    }
  }

  Future<void> updateBlock(
    BlockItem block,
    String type,
    String text, {
    String? propsJson,
  }) async {
    await _updateBlockInternal(
      block,
      type,
      text,
      propsJson: propsJson,
      retryOnRevisionConflict: true,
    );
  }

  Future<void> _updateBlockInternal(
    BlockItem block,
    String type,
    String text, {
    String? propsJson,
    required bool retryOnRevisionConflict,
  }) async {
    final latest = _findBlock(block.id) ?? block;
    final normalizedType = _normalizeType(type);
    final normalizedProps = normalizedType == 'table' &&
            (propsJson == null || propsJson.trim().isEmpty)
        ? latest.propsJson ?? _defaultPropsForType('table')
        : propsJson ?? latest.propsJson;

    if (latest.type == normalizedType &&
        latest.textContent == text &&
        latest.propsJson == normalizedProps) {
      return;
    }

    final lease = await acquireLease(latest);
    if (lease == null || !lease.canWrite) {
      error = lease == null
          ? 'Không lấy được quyền sửa block.'
          : 'Block đang được ${lease.holderDisplayName ?? 'người khác'} chỉnh sửa.';
      notifyListeners();
      return;
    }

    try {
      final mutation = await _repository.updateBlock(
        latest,
        expectedRevision: currentRevision,
        editorSessionId: editorSessionId,
        textContent: text,
        type: normalizedType,
        propsJson: normalizedProps,
      );

      _applyMutation(mutation);
      error = null;
      notifyListeners();
    } catch (err) {
      if (retryOnRevisionConflict && _isRevisionConflict(err)) {
        await refreshDocument();

        final fresh = _findBlock(block.id);
        if (fresh != null) {
          await _updateBlockInternal(
            fresh,
            normalizedType,
            text,
            propsJson: normalizedProps,
            retryOnRevisionConflict: false,
          );
        }
        return;
      }

      error = _message(err);
      notifyListeners();
    }
  }

  Future<BlockItem?> duplicateBlock(BlockItem block) async {
    final page = selectedPage;
    if (page == null) return null;

    final latest = _findBlock(block.id) ?? block;

    try {
      final mutation = await _repository.createBlock(
        page.id,
        expectedRevision: currentRevision,
        type: latest.type,
        textContent: latest.textContent,
        propsJson: latest.propsJson,
        previousBlockId: latest.id,
      );

      _applyMutation(mutation);
      notifyListeners();
      return mutation.block;
    } catch (err) {
      if (_isRevisionConflict(err)) {
        await refreshDocument();
        return duplicateBlock(block);
      }

      error = _message(err);
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteBlock(BlockItem block) async {
    final latest = _findBlock(block.id) ?? block;
    final lease = await acquireLease(latest);
    if (lease == null || !lease.canWrite) {
      error = lease == null
          ? 'Không lấy được quyền xóa block.'
          : 'Block đang được ${lease.holderDisplayName ?? 'người khác'} chỉnh sửa.';
      notifyListeners();
      return;
    }

    try {
      final mutation = await _repository.deleteBlock(
        latest,
        expectedRevision: currentRevision,
        editorSessionId: editorSessionId,
      );
      _applyDeleteMutation(mutation, deletedIds: [latest.id]);
      leases = Map<String, BlockLease>.from(leases)..remove(latest.id);
      notifyListeners();
    } catch (err) {
      if (_isRevisionConflict(err)) {
        await refreshDocument();
        return deleteBlock(block);
      }

      error = _message(err);
      notifyListeners();
    }
  }

  Future<void> moveBlockUp(BlockItem block) async {
    final index = blocks.indexWhere((item) => item.id == block.id);
    if (index <= 0) return;
    await _moveBlock(block,
        previousBlockId: index - 2 >= 0 ? blocks[index - 2].id : null,
        nextBlockId: blocks[index - 1].id);
  }

  Future<void> moveBlockDown(BlockItem block) async {
    final index = blocks.indexWhere((item) => item.id == block.id);
    if (index < 0 || index >= blocks.length - 1) return;
    await _moveBlock(block,
        previousBlockId: blocks[index + 1].id,
        nextBlockId: index + 2 < blocks.length ? blocks[index + 2].id : null);
  }

  Future<void> _moveBlock(
    BlockItem block, {
    String? previousBlockId,
    String? nextBlockId,
  }) async {
    final latest = _findBlock(block.id) ?? block;
    final lease = await acquireLease(latest);
    if (lease == null || !lease.canWrite) {
      error = lease == null
          ? 'Không lấy được quyền di chuyển block.'
          : 'Block đang được ${lease.holderDisplayName ?? 'người khác'} chỉnh sửa.';
      notifyListeners();
      return;
    }

    try {
      final mutation = await _repository.moveBlock(
        latest,
        expectedRevision: currentRevision,
        editorSessionId: editorSessionId,
        previousBlockId: previousBlockId,
        nextBlockId: nextBlockId,
      );

      _applyMutation(mutation);
      notifyListeners();
    } catch (err) {
      if (_isRevisionConflict(err)) {
        await refreshDocument();
        return _moveBlock(block,
            previousBlockId: previousBlockId, nextBlockId: nextBlockId);
      }

      error = _message(err);
      notifyListeners();
    }
  }

  Future<BlockLease?> acquireLease(BlockItem block) async {
    final current = leases[block.id];
    if (current != null && current.canWrite) {
      _ensureLeaseRenewal();
      return current;
    }

    try {
      final lease = await _repository.acquireBlockLease(
        block,
        editorSessionId: editorSessionId,
      );

      leases = Map<String, BlockLease>.from(leases)..[block.id] = lease;
      if (lease.canWrite) _ensureLeaseRenewal();
      notifyListeners();
      return lease;
    } catch (err) {
      error = _message(err);
      notifyListeners();
      return null;
    }
  }

  Future<void> startEditingBlock(BlockItem block) async {
    activeBlockId = block.id;
    final lease = await acquireLease(block);

    if (lease?.canWrite == true) {
      await _realtime.sendBlockEditingState(
        pageId: block.pageId,
        blockId: block.id,
        editorSessionId: editorSessionId,
        isEditing: true,
      );
    }

    notifyListeners();
  }

  Future<void> finishEditingBlock(BlockItem block) async {
    if (activeBlockId == block.id) activeBlockId = null;

    await _realtime.sendBlockEditingState(
      pageId: block.pageId,
      blockId: block.id,
      editorSessionId: editorSessionId,
      isEditing: false,
    );

    await releaseLease(block);
    notifyListeners();
  }

  Future<void> releaseLease(BlockItem block) async {
    final current = leases[block.id];
    if (current == null || !current.isHeldByCurrentUser) return;

    try {
      await _repository.releaseBlockLease(
        block,
        editorSessionId: editorSessionId,
      );
    } catch (_) {
      // Release is best-effort. Lease will expire server-side if this fails.
    }

    leases = Map<String, BlockLease>.from(leases)..remove(block.id);
    _stopLeaseRenewalIfIdle();
  }

  bool isLeaseHeldByMe(BlockItem block) => leases[block.id]?.canWrite == true;

  Future<void> sendDraft(BlockItem block, String text) async {
    final page = selectedPage;
    if (page == null) return;

    final latest = _findBlock(block.id) ?? block;
    final lease = leases[latest.id];

    if (lease == null || !lease.canWrite) {
      await acquireLease(latest);
    }

    if (leases[latest.id]?.canWrite != true) return;

    _draftSequence += 1;
    await _realtime.sendBlockDraft(
      pageId: page.id,
      blockId: latest.id,
      editorSessionId: editorSessionId,
      baseRevision: currentRevision,
      clientSequence: _draftSequence,
      textContent: text,
      type: latest.type,
      propsJson: latest.propsJson,
    );
  }

  String _defaultTextForType(String type) {
    return switch (_normalizeType(type)) {
      'heading_1' => 'Tiêu đề lớn',
      'heading_2' => 'Tiêu đề nhỏ',
      'heading_3' => 'Tiêu đề',
      'todo' => 'Việc cần làm',
      'quote' => 'Trích dẫn',
      'code' => '// code',
      'image' => '',
      'divider' => '',
      'table' => '',
      _ => '',
    };
  }

  String? _defaultPropsForType(String type) {
    if (_normalizeType(type) != 'table') return null;
    return jsonEncode({
      'rows': [
        ['Name', 'Status'],
        ['', ''],
      ],
      'hasHeader': true,
    });
  }

  void _bindRealtime() {
    if (_unsubscribe.isNotEmpty) return;

    for (final event in ['PageCreated', 'PageUpdated', 'PageDeleted']) {
      _unsubscribe.add(_realtime.on(event, (payload) {
        final id = workspaceId;
        if (id != null &&
            (payload.workspaceId == null || payload.workspaceId == id)) {
          _debounced(() => isTrashView ? loadTrash(id) : loadPages(id));
        }
      }));
    }

    _unsubscribe.add(_realtime.on(
      'PageMetadataUpdated',
      _handlePageMetadataUpdated,
    ));
    _unsubscribe.add(_realtime.on('BlockCreated', _handleBlockCreated));
    _unsubscribe.add(_realtime.on('BlockUpdated', _handleBlockUpdated));
    _unsubscribe.add(_realtime.on('BlockMoved', _handleBlockUpdated));
    _unsubscribe.add(_realtime.on('BlockDeleted', _handleBlockDeleted));
    _unsubscribe
        .add(_realtime.on('BlockDraftChanged', _handleBlockDraftChanged));
    _unsubscribe
        .add(_realtime.on('BlockLeaseChanged', _handleBlockLeaseChanged));
    _unsubscribe
        .add(_realtime.on('PagePresenceChanged', (_) => notifyListeners()));
  }

  void _handlePageMetadataUpdated(RealtimeEvent event) {
    final page = selectedPage;
    if (page == null) return;
    if (event.pageId != null && event.pageId != page.id) return;

    final payload = event.payloadMap;
    if (payload.isEmpty) return;

    final updated = PageItem.fromJson({
      ...payload,
      if (event.workspaceId != null) 'workspaceId': event.workspaceId,
      if (event.pageId != null) 'id': event.pageId,
      if (event.revision != null) 'currentRevision': event.revision,
    });

    _replacePage(updated);
    currentRevision = updated.currentRevision;
    notifyListeners();
  }

  void _handleBlockCreated(RealtimeEvent event) {
    if (!_isCurrentPageEvent(event)) return;
    final mutation = _mutationFromEvent(event);
    if (mutation.block == null) return;
    _applyMutation(mutation);
    notifyListeners();
  }

  void _handleBlockUpdated(RealtimeEvent event) {
    if (!_isCurrentPageEvent(event)) return;
    final mutation = _mutationFromEvent(event);
    if (mutation.block == null) return;
    _applyMutation(mutation);
    notifyListeners();
  }

  void _handleBlockDeleted(RealtimeEvent event) {
    if (!_isCurrentPageEvent(event)) return;

    final payload = event.payloadMap;
    final deletedIds = <String>{
      if (event.blockId != null) event.blockId!,
      if (payload['blockId'] != null) payload['blockId'].toString(),
      ..._stringList(payload['deletedBlockIds']),
    }.where((id) => id.trim().isNotEmpty).toList();

    final mutation = BlockMutation(
      pageId:
          event.pageId ?? asString(payload['pageId'], selectedPage?.id ?? ''),
      blockId: event.blockId ?? payload['blockId']?.toString(),
      appliedRevision:
          event.revision ?? asInt(payload['appliedRevision'], currentRevision),
      block: null,
    );

    _applyDeleteMutation(mutation, deletedIds: deletedIds);
    notifyListeners();
  }

  void _handleBlockDraftChanged(RealtimeEvent event) {
    if (!_isCurrentPageEvent(event)) return;

    final payload = event.payloadMap;
    final remoteEditorSessionId = asString(payload['editorSessionId']);
    if (remoteEditorSessionId == editorSessionId) return;

    final blockId = event.blockId ?? payload['blockId']?.toString();
    if (blockId == null || blockId.isEmpty) return;

    if (activeBlockId == blockId) return;

    final index = blocks.indexWhere((item) => item.id == blockId);
    if (index < 0) return;

    final current = blocks[index];
    final next = current.copyWith(
      type: payload['type'] == null
          ? current.type
          : _normalizeType(payload['type'].toString()),
      textContent: payload['textContent'] == null
          ? current.textContent
          : payload['textContent'].toString(),
      propsJson: payload['propsJson'] == null
          ? current.propsJson
          : payload['propsJson'].toString(),
    );

    final updated = List<BlockItem>.from(blocks);
    updated[index] = next;
    blocks = updated;
    notifyListeners();
  }

  void _handleBlockLeaseChanged(RealtimeEvent event) {
    if (!_isCurrentPageEvent(event)) return;

    final payload = event.payloadMap;
    final lease = BlockLease.fromJson(payload);
    if (lease.blockId.isEmpty) return;

    final next = Map<String, BlockLease>.from(leases);
    if (lease.isReleased) {
      next.remove(lease.blockId);
    } else {
      next[lease.blockId] = lease;
    }

    leases = next;
    _stopLeaseRenewalIfIdle();
    notifyListeners();
  }

  bool _isCurrentPageEvent(RealtimeEvent event) {
    final page = selectedPage;
    if (page == null) return false;
    return event.pageId == null || event.pageId == page.id;
  }

  BlockMutation _mutationFromEvent(RealtimeEvent event) {
    final payload = event.payloadMap;
    return BlockMutation.fromJson({
      ...payload,
      if (event.pageId != null) 'pageId': event.pageId,
      if (event.blockId != null) 'blockId': event.blockId,
      if (event.revision != null) 'appliedRevision': event.revision,
    });
  }

  void _applyMutation(BlockMutation mutation) {
    if (mutation.appliedRevision > currentRevision) {
      currentRevision = mutation.appliedRevision;
      _syncSelectedPageRevision();
    }

    final block = mutation.block;
    if (block == null) return;

    final next = List<BlockItem>.from(blocks);
    final index = next.indexWhere((item) => item.id == block.id);
    if (index < 0) {
      next.add(block);
    } else {
      next[index] = block;
    }

    blocks = _sortBlocks(next);
  }

  void _applyDeleteMutation(
    BlockMutation mutation, {
    required Iterable<String> deletedIds,
  }) {
    if (mutation.appliedRevision > currentRevision) {
      currentRevision = mutation.appliedRevision;
      _syncSelectedPageRevision();
    }

    final ids = deletedIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty && mutation.blockId != null) {
      ids.add(mutation.blockId!);
    }

    blocks = blocks.where((item) => !ids.contains(item.id)).toList();
    final nextLeases = Map<String, BlockLease>.from(leases);
    for (final id in ids) {
      nextLeases.remove(id);
    }
    leases = nextLeases;
  }

  void _syncSelectedPageRevision() {
    final page = selectedPage;
    if (page == null) return;

    selectedPage = page.copyWith(currentRevision: currentRevision);
    pages = pages
        .map((item) => item.id == page.id
            ? item.copyWith(currentRevision: currentRevision)
            : item)
        .toList();
  }

  void _replacePage(PageItem page) {
    pages = pages.map((item) => item.id == page.id ? page : item).toList();
    if (selectedPage?.id == page.id) selectedPage = page;
  }

  List<BlockItem> _sortBlocks(List<BlockItem> source) {
    final next = List<BlockItem>.from(source);
    next.sort((a, b) {
      final parentCompare =
          (a.parentBlockId ?? '').compareTo(b.parentBlockId ?? '');
      if (parentCompare != 0) return parentCompare;
      final orderCompare = a.orderKey.compareTo(b.orderKey);
      if (orderCompare != 0) return orderCompare;
      return a.id.compareTo(b.id);
    });
    return next;
  }

  BlockItem? _findBlock(String id) {
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  void _debounced(Future<void> Function() action) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      action();
    });
  }

  void _startPageHeartbeat(String pageId) {
    _pageHeartbeat?.cancel();
    _pageHeartbeat = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _realtime.heartbeatPage(pageId),
    );
  }

  void _ensureLeaseRenewal() {
    if (_leaseRenewal?.isActive == true) return;

    _leaseRenewal = Timer.periodic(const Duration(seconds: 20), (_) async {
      final heldIds = leases.entries
          .where((entry) => entry.value.canWrite)
          .map((entry) => entry.key)
          .toList();

      if (heldIds.isEmpty) {
        _stopLeaseRenewalIfIdle();
        return;
      }

      for (final id in heldIds) {
        final block = _findBlock(id);
        if (block == null) continue;

        try {
          final renewed = await _repository.renewBlockLease(
            block,
            editorSessionId: editorSessionId,
          );
          leases = Map<String, BlockLease>.from(leases)..[id] = renewed;
        } catch (_) {
          leases = Map<String, BlockLease>.from(leases)..remove(id);
        }
      }

      notifyListeners();
      _stopLeaseRenewalIfIdle();
    });
  }

  void _stopLeaseRenewalIfIdle() {
    if (leases.values.any((lease) => lease.canWrite)) return;
    _leaseRenewal?.cancel();
    _leaseRenewal = null;
  }

  bool _isRevisionConflict(Object err) {
    if (err is ApiFailure && err.statusCode == 409) return true;
    final text = err.toString().toLowerCase();
    return text.contains('revision') ||
        text.contains('phiên bản') ||
        text.contains('conflict');
  }

  String _normalizeType(String type) {
    final value = type.trim().toLowerCase();
    return value.isEmpty ? 'paragraph' : value;
  }

  String _message(Object err) {
    if (err is ApiFailure) return err.message;
    return err.toString();
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const <String>[];
  }

  @override
  void dispose() {
    for (final off in _unsubscribe) {
      off();
    }
    _debounce?.cancel();
    _pageHeartbeat?.cancel();
    _leaseRenewal?.cancel();
    if (selectedPage != null) _realtime.leavePage(selectedPage!.id);
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}