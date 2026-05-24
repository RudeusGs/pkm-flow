# Block Based PKM Flutter

Mobile Flutter client được port lại từ Vue client theo hướng feature-based clean architecture.

## Kiến trúc

```txt
lib/
├── main.dart                         # chỉ boot app
├── app/                              # dependency graph + root app
├── core/
│   ├── config/                       # env/base URL
│   ├── network/                      # Dio API client
│   ├── realtime/                     # SignalR service + event envelope
│   ├── storage/                      # secure token store
│   ├── theme/                        # Notion-like mobile theme
│   └── utils/
├── features/
│   ├── auth/                         # domain/data/presentation
│   ├── workspaces/
│   ├── pages/                        # page + block editor mobile
│   ├── tasks/
│   ├── inbox/                        # notifications + messages
│   ├── social/
│   └── home/
└── shared/widgets/
```

## Realtime

Realtime nằm trong `lib/core/realtime/realtime_service.dart`, dùng SignalR hub:

```txt
/hubs/collaboration
```

Các feature tự subscribe event cần thiết:

- Pages: `PageCreated`, `PageUpdated`, `PageDeleted`, `BlockCreated`, `BlockUpdated`, `BlockDeleted`, `BlockDraftChanged`, `PagePresenceChanged`
- Tasks: `TaskCreated`, `TaskUpdated`, `TaskDeleted`, `TaskStatusChanged`, `RecommendationCreated`
- Inbox: `NotificationCreated`, `ConversationUpserted`, `MessageCreated`, `ConversationTyping`
- Social: `FriendRequestReceived`, `FriendRequestAccepted`, `FriendshipChanged`, `FriendRemoved`

Desktop-only đã bỏ: cursor chuột, pointer vị trí chuột, layout nhiều panel.

## Chạy project

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5029/api/v1
```

Real device cần đổi `10.0.2.2` thành LAN IP của máy chạy backend.
