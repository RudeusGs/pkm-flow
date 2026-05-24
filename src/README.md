# Block Based PKM Flutter Mobile

Flutter client đã được chuyển sang giao diện Notion mobile, tách feature-based clean architecture và có realtime SignalR.

## Điểm chính

- Workspace là tab đầu tiên: chọn/tạo workspace, xem page list, tạo page, members, invite email, share workspace qua tin nhắn.
- Notification không còn nằm chung với inbox: icon chuông ở góc phải, mở bottom sheet list thông báo.
- Tin nhắn có tab riêng: conversation list, chat realtime, hỗ trợ message dạng workspace share.
- Profile có chỉnh sửa tên, avatar URL và upload avatar qua `me/avatar-image`.
- Editor kiểu Notion mobile: title/icon đầu page, block menu, thêm paragraph/heading/todo/list/quote/code.
- Tasks có filter, tạo task, đổi trạng thái và AI recommendations.
- People có tìm user, gửi friend request và mở chat.

## Chạy với backend local của bạn

Backend hiện tại: `https://localhost:7286`

```bash
flutter clean
flutter pub get
flutter run -d chrome --web-port=60135 --dart-define=API_BASE_URL=https://localhost:7286/api/v1
```

Mặc định trong `lib/core/config/app_config.dart` cũng đã để:

```dart
https://localhost:7286/api/v1
```

Realtime hub tự suy ra:

```txt
https://localhost:7286/hubs/collaboration
```

## Lưu ý CORS

Flutter web origin ví dụ:

```txt
http://localhost:60135
```

Cần có trong backend `Cors:AllowedOrigins` và nhớ restart backend sau khi sửa config.
