import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;
  bool _isSubmitting = false;

  void _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入用户名和密码');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final auth = context.read<AuthService>();
    final success = auth.login(username, password);

    setState(() {
      _isSubmitting = false;
      if (!success) {
        _error = '用户名或密码错误';
      }
    });
  }

  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 退出按钮
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('退出应用'),
                            content: const Text('确定要退出环网柜监控系统吗？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  SystemNavigator.pop();
                                },
                                child: const Text('退出', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.exit_to_app, color: Colors.white70),
                      label: const Text('退出', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo区域
                          const Icon(Icons.sensors, size: 64, color: Colors.blue),
                          const SizedBox(height: 12),
                          const Text(
                            '环网柜监控系统',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '智能环境监控平台',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 32),

                          // 用户名
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: '用户名',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                            onChanged: (_) => _clearError(),
                          ),
                          const SizedBox(height: 8),

                          // 错误提示
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                            ),

                          // 登录按钮
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _login,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  : const Text('登 录', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 注册链接
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('还没有账号？', style: TextStyle(color: Colors.grey[600])),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                                  );
                                },
                                child: const Text('立即注册'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
