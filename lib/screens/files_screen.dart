// PCV · 文件屏（源码树浏览）
import 'dart:io';

import 'package:flutter/material.dart';

import '../editor_screen.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class FilesScreen extends StatefulWidget {
  final SettingsModel settings;
  const FilesScreen({super.key, required this.settings});

  @override
  State<FilesScreen> createState() => FilesScreenState();
}

class _Node {
  final String name;
  final String rel;
  final bool isDir;
  List<_Node> children = [];
  bool expanded = false;
  bool loaded = false;
  _Node(this.name, this.rel, this.isDir);
}

class FilesScreenState extends State<FilesScreen> {
  final ws = WorkspaceService.instance;
  final _rootNodes = <_Node>[];
  bool _loaded = false;
  String _base = '';

  @override
  void initState() {
    super.initState();
    ws.addListener(_onWs);
    _maybeLoad();
  }

  @override
  void dispose() {
    ws.removeListener(_onWs);
    super.dispose();
  }

  void _onWs() {
    if (!_loaded) _maybeLoad();
    if (mounted) setState(() {});
  }

  void _maybeLoad() {
    if (_loaded || ws.phase != WPhase.ready || ws.src == null) return;
    _loaded = true;
    _base = ws.src!.path;
    _loadChildren(_rootNodes, _base, '');
  }

  void _loadChildren(List<_Node> into, String absDir, String relPrefix) {
    try {
      final dir = Directory(absDir);
      final entries = dir.listSync(followLinks: false);
      final dirs = <_Node>[];
      final files = <_Node>[];
      for (final e in entries) {
        final name = e.path.split('/').last;
        if (name.startsWith('.')) continue;
        final rel = relPrefix.isEmpty ? name : '$relPrefix/$name';
        if (e is Directory) {
          dirs.add(_Node(name, rel, true));
        } else if (e is File) {
          files.add(_Node(name, rel, false));
        }
      }
      dirs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      into
        ..clear()
        ..addAll(dirs)
        ..addAll(files);
    } catch (_) {}
  }

  Future<void> _toggle(_Node n) async {
    if (!n.isDir) {
      await _open(n);
      return;
    }
    setState(() {
      n.expanded = !n.expanded;
      if (n.expanded && !n.loaded) {
        _loadChildren(
          n.children,
          '$_base/${n.rel}',
          n.rel,
        );
        n.loaded = true;
      }
    });
  }

  Future<void> _open(_Node n) async {
    widget.settings.touchRecent(n.rel);
    await EditorScreen.open(context, widget.settings, n.rel);
    if (mounted) setState(() {});
  }

  void _showFileMenu(_Node n, TapDownDetails d) {
    final p = palOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.elev,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: p.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      n.rel,
                      style: TextStyle(
                        fontSize: 13,
                        color: p.t2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.open_in_new_rounded, color: p.blue),
              title: Text('打开', style: TextStyle(color: p.t1)),
              onTap: () {
                Navigator.pop(ctx);
                _open(n);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline_rounded, color: p.t3),
              title: Text('文件信息', style: TextStyle(color: p.t1)),
              onTap: () async {
                Navigator.pop(ctx);
                await _showInfo(n);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInfo(_Node n) async {
    final f = File('$_base/${n.rel}');
    String info;
    try {
      final len = await f.length();
      var lines = 0;
      if (len < 512 * 1024) {
        final t = await f.readAsString();
        lines = '\n'.allMatches(t).length + 1;
      }
      final stat = await f.stat();
      info = '路径：${n.rel}\n'
          '大小：${fmtBytes(len)}\n'
          '行数：${lines > 0 ? lines : '—'}\n'
          '修改：${stat.modified.toString().substring(0, 19)}';
    } catch (e) {
      info = '读取失败：$e';
    }
    if (!mounted) return;
    final p = palOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('文件信息',
            style: TextStyle(fontSize: 16, color: p.t1)),
        content: SelectableText(
          info,
          style: TextStyle(fontSize: 13, color: p.t2, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('文件'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () {
              setState(() {
                _rootNodes.clear();
                _loaded = false;
                _maybeLoad();
              });
            },
            icon: Icon(Icons.refresh_rounded, size: 20, color: p.t2),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final p = palOf(context);
    if (ws.phase == WPhase.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: p.red, size: 42),
              const SizedBox(height: 12),
              Text(ws.error ?? '工作区初始化失败',
                  style: TextStyle(color: p.t2), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => ws.ensure(force: true),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_loaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text('正在准备源码…', style: TextStyle(color: p.t3, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 16, color: p.t3),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LINGOS ${ws.meta['version'] ?? ''} · 内置源码（可编辑副本）',
                  style: TextStyle(fontSize: 12.5, color: p.t2),
                ),
              ),
            ],
          ),
        ),
        for (final n in _rootNodes) ..._renderNode(n, 0),
      ],
    );
  }

  List<Widget> _renderNode(_Node n, int depth) {
    final p = palOf(context);
    final rows = <Widget>[_nodeRow(context, n, depth, p)];
    if (n.isDir && n.expanded) {
      for (final c in n.children) {
        rows.addAll(_renderNode(c, depth + 1));
      }
      if (n.children.isEmpty) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: 28.0 + depth * 22),
          child: Text('（空）',
              style: TextStyle(fontSize: 12, color: p.t4)),
        ));
      }
    }
    return rows;
  }

  Widget _nodeRow(BuildContext context, _Node n, int depth, Pal p) {
    final accent = Theme.of(context).colorScheme.primary;
    IconData icon;
    Color iconColor;
    if (n.isDir) {
      icon = n.expanded
          ? Icons.folder_open_rounded
          : Icons.folder_rounded;
      iconColor = n.expanded ? accent : p.t2;
    } else {
      final style = fileStyleFor(n.name, p);
      icon = style.$1;
      iconColor = style.$2;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggle(n),
        onSecondaryTapDown: (d) => _showFileMenu(n, d),
        onLongPress: () => _showFileMenu(
          n,
          TapDownDetails(globalPosition: Offset.zero),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0 + depth * 20,
            right: 16,
            top: 9,
            bottom: 9,
          ),
          child: Row(
            children: [
              if (n.isDir)
                AnimatedRotation(
                  turns: n.expanded ? .25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 16, color: p.t4),
                )
              else
                const SizedBox(width: 16),
              const SizedBox(width: 4),
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  n.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: p.t1,
                    fontWeight:
                        n.isDir ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
