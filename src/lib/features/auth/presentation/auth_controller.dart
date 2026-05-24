import 'package:flutter/foundation.dart';

import '../../../core/realtime/realtime_service.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

class AuthController extends ChangeNotifier {
  AuthController(
      {required AuthRepository repository, required RealtimeService realtime})
      : _repository = repository,
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
        } catch (_) {}
        await _realtime.start();
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
      await _realtime.start();
    });
  }

  Future<bool> register(
      {required String userName,
      required String email,
      required String fullName,
      required String password}) async {
    return _run(() async {
      await _repository.register(
          userName: userName,
          email: email,
          fullName: fullName,
          password: password);
    });
  }

  Future<bool> updateProfile(String fullName) async {
    return _run(() async {
      user = await _repository.updateProfile(fullName: fullName);
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    await _realtime.stop();
    user = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
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
