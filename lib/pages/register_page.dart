import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  void _register() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (username.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = '请填写所有字段');
      return;
    }
    if (password != confirm) {
      setState(() => _error = '两次密码不一致');
      return;
    }

    final auth = context.read<AuthService>();
    // 注册默认为普通用户
    final err = auth.register(username, password, UserRole.user);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    // 注册成功，返回登录页
    Navigator.pop(context);
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blueAccent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add, size: 48, color: Colors.blue),
                      const SizedBox(height: 12),
                      const Text('创建账号', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('注册后默认为普通用户', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      const SizedBox(height: 24),

                      // 用户名
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: '用户名',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: '至少3个字符',
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 16),

                      // 密码
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: '至少4个字符',
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 16),

                      // 确认密码
                      TextField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: '确认密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        onSubmitted: (_) => _register(),
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 8),

                      // 错误提示
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        ),

                      // 注册按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('注 册', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
