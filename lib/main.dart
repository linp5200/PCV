// PCV · 便携代码图形化工作台（Portable Code Visual Workbench）
// 入口：加载设置 → 构建主题 → 启动外壳（四屏：首页/文件/搜索/设置）
import 'package:flutter/material.dart';

import 'screens/files_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsModel();
  await settings.load();
  runApp(PcvApp(settings: settings));
}

class PcvApp extends StatelessWidget {
  final SettingsModel settings;
  const PcvApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (_, __) {
        final mode = settings.themeMode;
        final themeMode = mode == 'dark'
            ? ThemeMode.dark
            : mode == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
        final accent = accentOf(settings.accent);
        return MaterialApp(
          title: '代码工作台',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: buildPcvTheme(dark: false, accent: accent),
          darkTheme: buildPcvTheme(dark: true, accent: accent),
          home: Shell(settings: settings),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  final SettingsModel settings;
  const Shell({super.key, required this.settings});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _filesKey = GlobalKey<FilesScreenState>();
  final _searchKey = GlobalKey<SearchScreenState>();

  @override
  void initState() {
    super.initState();
    // 启动时确保内置源码就绪（首次：解压；之后：直接读 meta）
    WorkspaceService.instance.ensure();
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        settings: widget.settings,
        onOpenFiles: () => _go(1),
        onOpenSearch: () => _go(2),
      ),
      FilesScreen(key: _filesKey, settings: widget.settings),
      SearchScreen(key: _searchKey, settings: widget.settings),
      SettingsScreen(settings: widget.settings),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: PcvNavBar(index: _index, onTap: _go),
    );
  }
}
