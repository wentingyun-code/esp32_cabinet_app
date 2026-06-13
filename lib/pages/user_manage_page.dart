import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

class UserManagePage extends StatelessWidget {
  const UserManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final users = auth.users;
    final currentUsername = auth.currentUser?.username ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('用户管理'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isCurrentUser = user.username == currentUsername;
        final isDefaultAdmin = user.username.startsWith('admin');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 头像
                CircleAvatar(
                  backgroundColor: user.isAdmin ? Colors.blue : Colors.grey,
                  child: Icon(
                    user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '当前',
                                style: TextStyle(fontSize: 11, color: Colors.green),
                              ),
                            ),
                          ],
                          if (isDefaultAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '预置',
                                style: TextStyle(fontSize: 11, color: Colors.orange),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.roleLabel,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // 操作按钮
                if (!isDefaultAdmin) ...[
                  // 切换角色
                  IconButton(
                    icon: Icon(
                      user.isAdmin ? Icons.person_remove : Icons.admin_panel_settings_outlined,
                      size: 22,
                    ),
                    tooltip: user.isAdmin ? '降为普通用户' : '升为管理员',
                    onPressed: () => _confirmChangeRole(context, user),
                  ),
                  // 删除
                  if (!isCurrentUser)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 22, color: Colors.red),
                      tooltip: '删除用户',
                      onPressed: () => _confirmDeleteUser(context, user),
                    ),
                ],
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  void _confirmChangeRole(BuildContext context, UserModel user) {
    final newRole = user.isAdmin ? UserRole.user : UserRole.admin;
    final action = user.isAdmin ? '降为普通用户' : '升为管理员';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action),
        content: Text('确定将 ${user.username} $action 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthService>();
              final err = await auth.changeRole(user.username, newRole);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已将 ${user.username} $action')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('确定删除用户 ${user.username} 吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthService>();
              final err = await auth.deleteUser(user.username);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除用户 ${user.username}')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
