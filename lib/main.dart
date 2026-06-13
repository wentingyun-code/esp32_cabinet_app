import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/cabinet_data.dart';
import 'models/user_model.dart';
import 'services/thingsboard_service.dart';
import 'pages/data_display_page.dart';
import 'pages/control_page.dart';
import 'pages/history_page.dart';
import 'pages/user_manage_page.dart';
import 'pages/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final cabinetData = CabinetData();
  final thingsBoardService = ThingsBoardService(cabinetData);
  final authService = AuthService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cabinetData),
        ChangeNotifierProvider.value(value: authService),
        Provider.value(value: thingsBoardService),
      ],
      child: const AppRoot(),
    ),
  );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Key _appKey = UniqueKey();

  void _rebuildApp() {
    setState(() {
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _appKey,
      child: MyApp(onRebuild: _rebuildApp),
    );
  }
}

class MyApp extends StatefulWidget {
  final VoidCallback onRebuild;

  const MyApp({super.key, required this.onRebuild});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      authService.init();
      final tbService = context.read<ThingsBoardService>();
      tbService.connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '环网柜监控系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// 登录状态守卫：未登录显示登录页，已登录显示主页
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.isLoggedIn) {
      return MainNavigation(
        isAdmin: auth.isAdmin,
        username: auth.currentUser!.username,
        onLogout: () => auth.logout(),
      );
    }
    return const LoginPage();
  }
}

class MainNavigation extends StatefulWidget {
  final bool isAdmin;
  final String username;
  final VoidCallback onLogout;

  const MainNavigation({
    super.key,
    required this.isAdmin,
    required this.username,
    required this.onLogout,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // 管理员4个Tab，普通用户2个Tab
  List<GlobalKey<NavigatorState>> get _navigatorKeys => widget.isAdmin
      ? [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()]
      : [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Widget _buildPage(int index) {
    if (widget.isAdmin) {
      switch (index) {
        case 0: return DataDisplayPage(onRebuild: () {});
        case 1: return const ControlPage();
        case 2: return const UserManagePage();
        case 3: return const HistoryPage();
        default: return DataDisplayPage(onRebuild: () {});
      }
    } else {
      switch (index) {
        case 0: return DataDisplayPage(onRebuild: () {});
        case 1: return const HistoryPage();
        default: return DataDisplayPage(onRebuild: () {});
      }
    }
  }

  List<BottomNavigationBarItem> get _navItems {
    if (widget.isAdmin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: '数据监控',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_remote_outlined),
          activeIcon: Icon(Icons.settings_remote),
          label: '设备控制',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outlined),
          activeIcon: Icon(Icons.people),
          label: '人员管理',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: '历史数据',
        ),
      ];
    }
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: '数据监控',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.history_outlined),
        activeIcon: Icon(Icons.history),
        label: '历史数据',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final navKeys = _navigatorKeys;
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text(
          '环网柜监控系统',
          overflow: TextOverflow.visible,
          softWrap: false,
        ),
        actions: [
          Consumer<CabinetData>(
            builder: (_, data, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: data.isConnected ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: data.isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.isConnected ? '在线' : '离线',
                    style: TextStyle(
                      fontSize: 12,
                      color: data.isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('退出登录'),
                  content: const Text('确定要退出当前账号吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onLogout();
                      },
                      child: const Text('退出', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(navKeys.length, (i) => Navigator(
          key: navKeys[i],
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => _buildPage(i),
          ),
        )),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        items: _navItems,
      ),
    );
  }
}
