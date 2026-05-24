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
  });

  final String id;
  final String pageId;
  final String type;
  final String textContent;
  final String? propsJson;
  final String? parentBlockId;
  final String orderKey;

  factory BlockItem.fromJson(JsonMap json) => BlockItem(
        id: asString(json['id']),
        pageId: asString(json['pageId']),
        type: asString(json['type'], 'paragraph'),
        textContent: asString(json['textContent']),
        propsJson: json['propsJson']?.toString(),
        parentBlockId: json['parentBlockId']?.toString(),
        orderKey: asString(json['orderKey']),
      );

  BlockItem copyWith({String? type, String? textContent, String? propsJson}) =>
      BlockItem(
        id: id,
        pageId: pageId,
        type: type ?? this.type,
        textContent: textContent ?? this.textContent,
        propsJson: propsJson ?? this.propsJson,
        parentBlockId: parentBlockId,
        orderKey: orderKey,
      );
}

class PageDocument {
  const PageDocument(
      {required this.pageId,
      required this.currentRevision,
      required this.blocks});

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
  const BlockMutation(
      {required this.pageId,
      this.blockId,
      required this.appliedRevision,
      this.block});

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
  final String? expiresAtUtc;
  final bool isHeldByCurrentUser;

  bool get canEdit => granted && isHeldByCurrentUser;

  factory BlockLease.fromJson(JsonMap json) => BlockLease(
        blockId: asString(json['blockId']),
        pageId: asString(json['pageId']),
        granted: asBool(json['granted']),
        status: asString(json['status']),
        holderUserId: json['holderUserId']?.toString(),
        holderDisplayName: json['holderDisplayName']?.toString(),
        expiresAtUtc: json['expiresAtUtc']?.toString(),
        isHeldByCurrentUser: asBool(json['isHeldByCurrentUser']),
      );
}
