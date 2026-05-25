import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required RealtimeService realtime,
  })  : _repository = repository,
        _realtime = realtime;

  final AuthRepository _repository;
  final RealtimeService _realtime;

  AuthUser? user;
  bool isBootstrapping = true;
  bool isBusy = false;
  String? error;

  bool get isAuthenticated => user != null;

  Future<void> bootstrap() async {
    isBootstrapping = true;
    notifyListeners();

    try {
      user = await _repository.cachedUser();

      if (await _repository.hasToken()) {
        try {
          user = await _repository.me();
        } catch (_) {
          // Giữ cached user nếu endpoint /me lỗi tạm thời.
        }

        _startRealtimeInBackground();
      }
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<bool> login(String userName, String password) async {
    return _run(() async {
      final token = await _repository.login(userName, password);
      user = token.user;

      // Không await realtime ở login để tránh hub lỗi làm kẹt/spam màn hình.
      _startRealtimeInBackground();
    });
  }

  Future<bool> register({
    required String userName,
    required String email,
    required String fullName,
    required String password,
  }) async {
    return _run(() async {
      await _repository.register(
        userName: userName,
        email: email,
        fullName: fullName,
        password: password,
      );
    });
  }

  Future<bool> updateProfile(String fullName, {String? avatarUrl}) async {
    return _run(() async {
      user = await _repository.updateProfile(
        fullName: fullName,
        avatarUrl: avatarUrl ?? user?.avatarUrl,
      );
    });
  }

  Future<bool> uploadAvatar(XFile image) async {
    return _run(() async {
      final bytes = await image.readAsBytes();
      user = await _repository.uploadAvatarImage(
        bytes: bytes,
        fileName: image.name,
      );
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _run(() async {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    await _realtime.stop();
    user = null;
    notifyListeners();
  }

  void _startRealtimeInBackground() {
    unawaited(_realtime.start(userInitiated: true));
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (isBusy) return false;

    isBusy = true;
    error = null;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (err) {
      error = err.toString();
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
