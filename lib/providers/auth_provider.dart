import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 簡易ログイン状態を管理する Provider。
///
/// パスワードは固定値 `zaiko`。
/// ログイン状態は `SharedPreferences` に保存し、ブラウザ更新後も維持される。
/// ログアウトすると保存値が削除され、再度ログイン画面に戻る。
class AuthProvider extends ChangeNotifier {
  static const String _prefsKey = 'is_logged_in';
  static const String _password = 'zaiko';

  bool _isLoggedIn = false;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;

  /// 起動時に呼ぶ。前回のログイン状態を読み込む。
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool(_prefsKey) ?? false;
    _isInitialized = true;
    notifyListeners();
  }

  /// パスワード検証。一致したら true を返してログイン状態を保存。
  Future<bool> login(String password) async {
    if (password == _password) {
      _isLoggedIn = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// ログアウト処理。保存されたログイン状態を削除して通知。
  Future<void> logout() async {
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }
}
