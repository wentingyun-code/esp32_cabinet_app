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
  UserModel? _currentUser;
  // 预置管理员账号（不可删除）
  final List<UserModel> _defaultAdmins = const [
    UserModel(username: 'admin1', password: 'admin1', role: UserRole.admin),
    UserModel(username: 'admin2', password: 'admin2', role: UserRole.admin),
    UserModel(username: 'admin3', password: 'admin3', role: UserRole.admin),
    UserModel(username: 'admin4', password: 'admin4', role: UserRole.admin),
    UserModel(username: 'admin5', password: 'admin5', role: UserRole.admin),
  ];

  late SharedPreferences _prefs;
  List<UserModel> _registeredUsers = [];

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadRegisteredUsers();
    notifyListeners();
  }

  void _loadRegisteredUsers() {
    final jsonList = _prefs.getStringList('registered_users') ?? [];
    _registeredUsers = jsonList
        .map((json) => UserModel.fromJson(json))
        .toList();
  }

  Future<void> _saveRegisteredUsers() async {
    final jsonList = _registeredUsers.map((u) => u.toJson()).toList();
    await _prefs.setStringList('registered_users', jsonList);
  }

  bool login(String username, String password) {
    // 检查预置管理员
    final defaultAdmin = _defaultAdmins.firstWhere(
      (u) => u.username == username && u.password == password,
      orElse: () => const UserModel(username: '', password: '', role: UserRole.user),
    );

    if (defaultAdmin.username.isNotEmpty) {
      _currentUser = defaultAdmin;
      notifyListeners();
      return true;
    }

    // 检查注册用户
    final registeredUser = _registeredUsers.firstWhere(
      (u) => u.username == username && u.password == password,
      orElse: () => const UserModel(username: '', password: '', role: UserRole.user),
    );

    if (registeredUser.username.isNotEmpty) {
      _currentUser = registeredUser;
      notifyListeners();
      return true;
    }

    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// 注册新用户，返回错误信息，null表示成功
  Future<String?> register(String username, String password, UserRole role) async {
    if (username.trim().isEmpty) return '用户名不能为空';
    if (username.trim().length < 3) return '用户名至少3个字符';
    if (password.length < 4) return '密码至少4个字符';

    // 检查是否已存在（包括预置账号）
    if (_defaultAdmins.any((u) => u.username == username)) {
      return '用户名已存在';
    }
    if (_registeredUsers.any((u) => u.username == username)) {
      return '用户名已存在';
    }

    _registeredUsers.add(UserModel(
      username: username.trim(),
      password: password,
      role: role,
    ));
    await _saveRegisteredUsers();
    notifyListeners();
    return null;
  }

  /// 获取所有用户列表（预置管理员 + 注册用户）
  List<UserModel> get users => [
    ..._defaultAdmins,
    ..._registeredUsers,
  ];

  /// 修改用户角色，返回错误信息，null表示成功
  Future<String?> changeRole(String username, UserRole newRole) async {
    // 不能修改预置管理员角色
    if (_defaultAdmins.any((u) => u.username == username)) {
      return '不能修改预置管理员角色';
    }

    final index = _registeredUsers.indexWhere((u) => u.username == username);
    if (index == -1) return '用户不存在';

    _registeredUsers[index] = UserModel(
      username: _registeredUsers[index].username,
      password: _registeredUsers[index].password,
      role: newRole,
    );
    await _saveRegisteredUsers();

    // 如果修改的是当前登录用户，更新当前用户引用
    if (_currentUser?.username == username) {
      _currentUser = _registeredUsers[index];
    }

    notifyListeners();
    return null;
  }

  /// 删除用户，返回错误信息，null表示成功
  Future<String?> deleteUser(String username) async {
    if (_currentUser?.username == username) return '不能删除当前登录用户';

    // 不能删除预置管理员
    if (_defaultAdmins.any((u) => u.username == username)) {
      return '不能删除预置管理员账号';
    }

    final beforeCount = _registeredUsers.length;
    _registeredUsers.removeWhere((u) => u.username == username);
    if (_registeredUsers.length == beforeCount) return '用户不存在';

    await _saveRegisteredUsers();
    notifyListeners();
    return null;
  }
}
