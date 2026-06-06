import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'models/cabinet_data.dart';
import 'services/thingsboard_service.dart';
import 'pages/data_display_page.dart';
import 'pages/control_page.dart';
import 'pages/history_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final cabinetData = CabinetData();
  final thingsBoardService = ThingsBoardService(cabinetData);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cabinetData),
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
      final tbService = context.read<ThingsBoardService>();
      tbService.connect();
    });
  }

  @override
  void dispose() {
    // 不在这里dispose MqttService，因为它的生命周期与AppRoot对齐
    // 主题切换会重建MyApp，如果dispose会导致MQTT永久死亡
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS || context.watch<CabinetData>().debugForceIOS;
    return MaterialApp(
      title: '环网柜监控系统',
      debugShowCheckedModeBanner: false,
      theme: isIOS
          ? ThemeData(
              brightness: Brightness.light,
              primaryColor: CupertinoColors.activeBlue,
              scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
              useMaterial3: true,
            )
          : ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            ),
      home: MainNavigation(onRebuild: widget.onRebuild),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback onRebuild;

  const MainNavigation({super.key, required this.onRebuild});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

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
    switch (index) {
      case 0:
        return DataDisplayPage(onRebuild: widget.onRebuild);
      case 1:
        return ControlPage();
      case 2:
        return HistoryPage();
      default:
        return DataDisplayPage(onRebuild: widget.onRebuild);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS || context.watch<CabinetData>().debugForceIOS;

    if (isIOS) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              label: '数据监控',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.gear),
              label: '设备控制',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.time),
              label: '历史数据',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return CupertinoTabView(
            navigatorKey: _navigatorKeys[index],
            builder: (_) => _buildPage(index),
          );
        },
      );
    } else {
      return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            Navigator(
              key: _navigatorKeys[0],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _buildPage(0),
              ),
            ),
            Navigator(
              key: _navigatorKeys[1],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _buildPage(1),
              ),
            ),
            Navigator(
              key: _navigatorKeys[2],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _buildPage(2),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: const [
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
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: '历史数据',
            ),
          ],
        ),
      );
    }
  }
}
