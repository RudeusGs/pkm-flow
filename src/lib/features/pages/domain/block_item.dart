import '../../../core/utils/json_utils.dart';

class BlockItem {
  const BlockItem({
    required this.id,
    required this.pageId,
    required this.type,
    required this.textContent,
    this.propsJson,
    this.parentBlockId,
    this.orderKey = '',
    this.schemaVersion = 1,
  });

  final String id;
  final String pageId;
  final String type;
  final String textContent;
  final String? propsJson;
  final String? parentBlockId;
  final String orderKey;
  final int schemaVersion;

  factory BlockItem.fromJson(JsonMap json) => BlockItem(
        id: asString(json['id']),
        pageId: asString(json['pageId']),
        type: asString(json['type'], 'paragraph'),
        textContent: asString(json['textContent']),
        propsJson: json['propsJson']?.toString(),
        parentBlockId: json['parentBlockId']?.toString(),
        orderKey: asString(json['orderKey']),
        schemaVersion: asInt(json['schemaVersion'], 1),
      );

  BlockItem copyWith({
    String? type,
    String? textContent,
    String? propsJson,
    String? parentBlockId,
    String? orderKey,
    int? schemaVersion,
  }) =>
      BlockItem(
        id: id,
        pageId: pageId,
        type: type ?? this.type,
        textContent: textContent ?? this.textContent,
        propsJson: propsJson ?? this.propsJson,
        parentBlockId: parentBlockId ?? this.parentBlockId,
        orderKey: orderKey ?? this.orderKey,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );
}

class PageDocument {
  const PageDocument({
    required this.pageId,
    required this.currentRevision,
    required this.blocks,
  });

  final String pageId;
  final int currentRevision;
  final List<BlockItem> blocks;

  factory PageDocument.fromJson(JsonMap json) => PageDocument(
        pageId: asString(json['pageId']),
        currentRevision: asInt(json['currentRevision']),
        blocks: asMapList(json['blocks']).map(BlockItem.fromJson).toList(),
      );
}

class BlockMutation {
  const BlockMutation({
    required this.pageId,
    this.blockId,
    required this.appliedRevision,
    this.block,
  });

  final String pageId;
  final String? blockId;
  final int appliedRevision;
  final BlockItem? block;

  factory BlockMutation.fromJson(JsonMap json) => BlockMutation(
        pageId: asString(json['pageId']),
        blockId: json['blockId']?.toString(),
        appliedRevision: asInt(json['appliedRevision']),
        block: json['block'] == null
            ? null
            : BlockItem.fromJson(asMap(json['block'])),
      );
}

class BlockLease {
  const BlockLease({
    required this.blockId,
    required this.pageId,
    required this.granted,
    required this.status,
    this.holderUserId,
    this.holderDisplayName,
    this.expiresAtUtc,
    this.isHeldByCurrentUser = false,
  });

  final String blockId;
  final String pageId;
  final bool granted;
  final String status;
  final String? holderUserId;
  final String? holderDisplayName;
  final DateTime? expiresAtUtc;
  final bool isHeldByCurrentUser;

  factory BlockLease.fromJson(JsonMap json) => BlockLease(
        blockId: asString(json['blockId']),
        pageId: asString(json['pageId']),
        granted: asBool(json['granted']),
        status: asString(json['status']),
        holderUserId: json['holderUserId']?.toString(),
        holderDisplayName: json['holderDisplayName']?.toString(),
        expiresAtUtc: DateTime.tryParse(asString(json['expiresAtUtc'])),
        isHeldByCurrentUser: asBool(json['isHeldByCurrentUser']),
      );

  bool get isReleased =>
      status.toLowerCase() == 'released' ||
      holderUserId == null ||
      holderUserId!.isEmpty;

  bool get isExpired {
    final expires = expiresAtUtc;
    if (expires == null) return false;
    return expires.toUtc().isBefore(DateTime.now().toUtc());
  }

  bool get canWrite => granted && isHeldByCurrentUser && !isExpired;
}
