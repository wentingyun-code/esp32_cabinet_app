import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, user }

class UserModel {
  final String username;
  final String password;
  final UserRole role;

  const UserModel({
    required this.username,
    required this.password,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  String get roleLabel => role == UserRole.admin ? '管理员' : '普通用户';

  Map<String, dynamic> toMap() => {
    'username': username,
    'password': password,
    'role': role.index,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    username: map['username'] as String,
    password: map['password'] as String,
    role: UserRole.values[map['role'] as int],
  );

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

class AuthService extends ChangeNotifier {
  static const _registeredUsersKey = 'registered_users';

  // 5个预置管理员账号
  static const List<UserModel> _defaultAdmins = [
    UserModel(username: 'admin1', password: 'admin1', role: UserRole.admin),
    UserModel(username: 'admin2', password: 'admin2', role: UserRole.admin),
    UserModel(username: 'admin3', password: 'admin3', role: UserRole.admin),
    UserModel(username: 'admin4', password: 'admin4', role: UserRole.admin),
    UserModel(username: 'admin5', password: 'admin5', role: UserRole.admin),
  ];

  List<UserModel> _users = [];
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> init() async {
    // 加载预置管理员
    _users = List.from(_defaultAdmins);

    // 从本地存储加载注册用户
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getStringList(_registeredUsersKey) ?? [];
      for (final jsonStr in usersJson) {
        final user = UserModel.fromJson(jsonStr);
        // 避免与预置管理员重复
        if (!_users.any((u) => u.username == user.username)) {
          _users.add(user);
        }
      }
    } catch (e) {
      debugPrint('加载注册用户失败: $e');
    }

    notifyListeners();
  }

  /// 保存注册用户到本地存储
  Future<void> _saveRegisteredUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 只保存非预置管理员的用户
      final registeredUsers = _users
          .where((u) => !_defaultAdmins.any((a) => a.username == u.username))
          .map((u) => u.toJson())
          .toList();
      await prefs.setStringList(_registeredUsersKey, registeredUsers);
    } catch (e) {
      debugPrint('保存注册用户失败: $e');
    }
  }

  bool login(String username, String password) {
    try {
      final user = _users.firstWhere(
        (u) => u.username == username && u.password == password,
      );
      _currentUser = user;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// 注册新用户，返回错误信息，null表示成功
  String? register(String username, String password, UserRole role) {
    if (username.trim().isEmpty) return '用户名不能为空';
    if (username.trim().length < 3) return '用户名至少3个字符';
    if (password.length < 4) return '密码至少4个字符';

    final exists = _users.any((u) => u.username == username.trim());
    if (exists) return '用户名已存在';

    final newUser = UserModel(
      username: username.trim(),
      password: password,
      role: role,
    );
    _users.add(newUser);
    _saveRegisteredUsers();
    notifyListeners();
    return null;
  }

  /// 获取所有用户列表
  List<UserModel> get users => List.unmodifiable(_users);

  /// 修改用户角色，返回错误信息，null表示成功
  String? changeRole(String username, UserRole newRole) {
    final index = _users.indexWhere((u) => u.username == username);
    if (index == -1) return '用户不存在';

    final old = _users[index];
    _users[index] = UserModel(username: old.username, password: old.password, role: newRole);

    // 如果修改的是当前登录用户，更新当前用户引用
    if (_currentUser?.username == username) {
      _currentUser = _users[index];
    }
    _saveRegisteredUsers();
    notifyListeners();
    return null;
  }

  /// 删除用户，返回错误信息，null表示成功
  String? deleteUser(String username) {
    if (_currentUser?.username == username) return '不能删除当前登录用户';
    final isDefault = _defaultAdmins.any((a) => a.username == username);
    if (isDefault) return '不能删除预置管理员账号';

    final index = _users.indexWhere((u) => u.username == username);
    if (index == -1) return '用户不存在';
    _users.removeAt(index);
    _saveRegisteredUsers();
    notifyListeners();
    return null;
  }
}
