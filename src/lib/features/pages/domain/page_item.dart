import '../../../core/utils/json_utils.dart';

class PageItem {
  const PageItem({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.parentPageId,
    this.icon,
    this.coverImage,
    this.isArchived = false,
    this.isFavorite = false,
    this.currentRevision = 0,
    this.archivedAt,
    this.createdDate,
    this.updatedDate,
    this.workspaceName,
    this.lastVisitedAtUtc,
    this.visitCount = 0,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String? parentPageId;
  final String? icon;
  final String? coverImage;
  final bool isArchived;
  final bool isFavorite;
  final int currentRevision;
  final String? archivedAt;
  final String? createdDate;
  final String? updatedDate;
  final String? workspaceName;
  final String? lastVisitedAtUtc;
  final int visitCount;

  factory PageItem.fromJson(JsonMap json) => PageItem(
        id: asString(json['id']),
        workspaceId: asString(json['workspaceId']),
        title: asString(json['title'], 'Untitled'),
        parentPageId: json['parentPageId']?.toString(),
        icon: json['icon']?.toString(),
        coverImage: json['coverImage']?.toString(),
        isArchived: asBool(json['isArchived']),
        isFavorite: asBool(json['isFavorite']),
        currentRevision: asInt(json['currentRevision']),
        archivedAt: json['archivedAt']?.toString(),
        createdDate: json['createdDate']?.toString(),
        updatedDate: json['updatedDate']?.toString(),
        workspaceName: json['workspaceName']?.toString(),
        lastVisitedAtUtc: json['lastVisitedAtUtc']?.toString(),
        visitCount: asInt(json['visitCount']),
      );

  PageItem copyWith({
    String? title,
    String? icon,
    String? coverImage,
    bool? isArchived,
    bool? isFavorite,
    int? currentRevision,
    String? archivedAt,
    String? createdDate,
    String? updatedDate,
    String? workspaceName,
    String? lastVisitedAtUtc,
    int? visitCount,
  }) =>
      PageItem(
        id: id,
        workspaceId: workspaceId,
        title: title ?? this.title,
        parentPageId: parentPageId,
        icon: icon ?? this.icon,
        coverImage: coverImage ?? this.coverImage,
        isArchived: isArchived ?? this.isArchived,
        isFavorite: isFavorite ?? this.isFavorite,
        currentRevision: currentRevision ?? this.currentRevision,
        archivedAt: archivedAt ?? this.archivedAt,
        createdDate: createdDate ?? this.createdDate,
        updatedDate: updatedDate ?? this.updatedDate,
        workspaceName: workspaceName ?? this.workspaceName,
        lastVisitedAtUtc: lastVisitedAtUtc ?? this.lastVisitedAtUtc,
        visitCount: visitCount ?? this.visitCount,
      );
}
