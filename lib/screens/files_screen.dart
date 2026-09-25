// PCV · 文件屏（源码树浏览 + 文件管理：新建/重命名/删除）
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
  bool expanded = false;
  List<_Node> children = [];
  _Node(this.name, this.rel, this.isDir);
}

class FilesScreenState extends State<FilesScreen> {
  final ps = ProjectsService.instance;
  final _rootNodes = <_Node>[];
  bool _loaded = false;
  String _loadedFor = '';

  @override
  void initState() {
    super.initState();
    ps.addListener(_onPs);
    _maybeLoad();
  }

  @override
  void dispose() {
    ps.removeListener(_onPs);
    super.dispose();
  }

  void _onPs() {
    if (mounted) {
      if (ps.currentId != _loadedFor) {
        _rootNodes.clear();
        _loaded = false;
      }
      setState(() {});
      _maybeLoad();
    }
  }

  void _maybeLoad() {
    if (_loaded || !ps.loaded || ps.unpacking || ps.current == null) return;
    _loadedFor = ps.currentId;
    _scan().then((nodes) {
      if (!mounted) return;
      setState(() {
        _rootNodes
          ..clear()
          ..addAll(nodes);
        _loaded = true;
      });
    });
  }

  String get _base => ps.current?.path ?? '';

  Future<List<_Node>> _scan() async {
    final dir = ps.currentDir;
    if (dir == null) return [];
    final entries = <FileSystemEntity>[];
    try {
      await for (final e in dir.list(followLinks: false)) {
        final name = e.path.split('/').last;
        if (name == '.pcv_drafts') continue;
        entries.add(e);
      }
    } catch (_) {}
    entries.sort((a, b) {
      final ad = a is Directory, bd = b is Directory;
      if (ad != bd) return ad ? -1 : 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
    return [
      for (final e in entries)
        _Node(
          e.path.split('/').last,
          e.path.substring(dir.path.length + 1),
          e is Directory,
        ),
    ];
  }

  Future<void> _toggle(_Node n) async {
    if (!n.isDir) {
      await _open(n);
      return;
    }
    if (!n.expanded) {
      final dir = Directory('$_base/${n.rel}');
      final entries = <FileSystemEntity>[];
      try {
        await for (final e in dir.list(followLinks: false)) {
          entries.add(e);
        }
      } catch (_) {}
      entries.sort((a, b) {
        final ad = a is Directory, bd = b is Directory;
        if (ad != bd) return ad ? -1 : 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      n.children = [
        for (final e in entries)
          _Node(
            e.path.split('/').last,
            e.path.substring(_base.length + 1),
            e is Directory,
          ),
      ];
    }
    setState(() => n.expanded = !n.expanded);
  }

  Future<void> _open(_Node n) async {
    widget.settings.touchRecent(n.rel);
    await EditorScreen.open(context, widget.settings, n.rel);
    if (mounted) {
      setState(() {});
      ps.refreshFileCount();
    }
  }

  // ---------- 文件管理 ----------

  Future<void> _newDialog({required bool isDir, String? parentRel}) async {
    final p = palOf(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text(
          isDir ? '新建文件夹' : '新建文件',
          style: TextStyle(fontSize: 16, color: p.t1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parentRel != null && parentRel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '位置：$parentRel/',
                  style: TextStyle(fontSize: 12, color: p.t3),
                ),
              ),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: p.t1),
              decoration: InputDecoration(
                hintText: isDir ? '文件夹名' : '文件名（含扩展名，如 main.py）',
                hintStyle: TextStyle(color: p.t4, fontSize: 13),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (name.contains('/')) {
      _toast('名称不能包含 /');
      return;
    }
    final rel = (parentRel == null || parentRel.isEmpty)
        ? name
        : '$parentRel/$name';
    try {
      if (isDir) {
        await Directory('$_base/$rel').create(recursive: true);
      } else {
        final f = File('$_base/$rel');
        await f.create(recursive: true);
        await f.writeAsString('');
      }
      _toast(isDir ? '已创建文件夹 $rel' : '已创建 $rel');
      await _reloadAfterChange();
    } catch (e) {
      _toast('创建失败：$e');
    }
  }

  Future<void> _renameDialog(_Node n) async {
    final p = palOf(context);
    final ctrl = TextEditingController(text: n.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('重命名', style: TextStyle(fontSize: 16, color: p.t1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: p.t1),
          decoration: InputDecoration(
            hintStyle: TextStyle(color: p.t4, fontSize: 13),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('重命名'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == n.name) return;
    if (newName.contains('/')) {
      _toast('名称不能包含 /');
      return;
    }
    final parent = n.rel.contains('/')
        ? n.rel.substring(0, n.rel.lastIndexOf('/'))
        : '';
    final newRel = parent.isEmpty ? newName : '$parent/$newName';
    try {
      if (n.isDir) {
        await Directory('$_base/${n.rel}').rename('$_base/$newRel');
      } else {
        await File('$_base/${n.rel}').rename('$_base/$newRel');
      }
      _toast('已重命名为 $newName');
      await _reloadAfterChange();
    } catch (e) {
      _toast('重命名失败：$e');
    }
  }

  Future<void> _deleteConfirm(_Node n) async {
    final p = palOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text(
          '删除「${n.name}」？',
          style: TextStyle(fontSize: 16, color: p.t1),
        ),
        content: Text(
          n.isDir ? '将删除该文件夹及其全部内容（不可撤销）。' : '将删除该文件（不可撤销）。',
          style: TextStyle(fontSize: 13.5, color: p.t2, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (n.isDir) {
        await Directory('$_base/${n.rel}').delete(recursive: true);
      } else {
        await File('$_base/${n.rel}').delete();
      }
      _toast('已删除 ${n.name}');
      await _reloadAfterChange();
    } catch (e) {
      _toast('删除失败：$e');
    }
  }

  Future<void> _showInfo(_Node n) async {
    final f = File('$_base/${n.rel}');
    String info;
    try {
      if (n.isDir) {
        var count = 0;
        await for (final e in Directory(
          '$_base/${n.rel}',
        ).list(recursive: true)) {
          if (e is File) count++;
        }
        info = '路径：${n.rel}\n类型：文件夹\n文件数：$count';
      } else {
        final len = await f.length();
        var lines = 0;
        if (len < 512 * 1024) {
          final t = await f.readAsString();
          lines = '\n'.allMatches(t).length + 1;
        }
        final stat = await f.stat();
        info =
            '路径：${n.rel}\n'
            '大小：${fmtBytes(len)}\n'
            '行数：${lines > 0 ? lines : '—'}\n'
            '修改：${stat.modified.toString().substring(0, 19)}';
      }
    } catch (e) {
      info = '读取失败：$e';
    }
    if (!mounted) return;
    final p = palOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('文件信息', style: TextStyle(fontSize: 16, color: p.t1)),
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

  Future<void> _reloadAfterChange() async {
    _loaded = false;
    _rootNodes.clear();
    if (mounted) setState(() {});
    _maybeLoad();
    ps.refreshFileCount();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ---------- 菜单 ----------

  void _showItemMenu(_Node n) {
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
                      style: TextStyle(fontSize: 13, color: p.t2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.isDir)
              ListTile(
                leading: Icon(Icons.open_in_new_rounded, color: p.blue),
                title: Text('打开', style: TextStyle(color: p.t1)),
                onTap: () {
                  Navigator.pop(ctx);
                  _open(n);
                },
              ),
            if (n.isDir) ...[
              ListTile(
                leading: Icon(Icons.note_add_outlined, color: p.green),
                title: Text('在此新建文件', style: TextStyle(color: p.t1)),
                onTap: () {
                  Navigator.pop(ctx);
                  _newDialog(isDir: false, parentRel: n.rel);
                },
              ),
              ListTile(
                leading: Icon(Icons.create_new_folder_outlined, color: p.teal),
                title: Text('在此新建文件夹', style: TextStyle(color: p.t1)),
                onTap: () {
                  Navigator.pop(ctx);
                  _newDialog(isDir: true, parentRel: n.rel);
                },
              ),
            ],
            ListTile(
              leading: Icon(
                Icons.drive_file_rename_outline_rounded,
                color: p.purple,
              ),
              title: Text('重命名', style: TextStyle(color: p.t1)),
              onTap: () {
                Navigator.pop(ctx);
                _renameDialog(n);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: p.red),
              title: Text('删除', style: TextStyle(color: p.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteConfirm(n);
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline_rounded, color: p.t3),
              title: Text('详细信息', style: TextStyle(color: p.t1)),
              onTap: () {
                Navigator.pop(ctx);
                _showInfo(n);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewMenu() async {
    final p = palOf(context);
    final v = await showModalBottomSheet<String>(
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
            ListTile(
              leading: Icon(Icons.insert_drive_file_outlined, color: p.blue),
              title: Text('新建文件', style: TextStyle(color: p.t1)),
              subtitle: Text(
                '在项目根目录创建',
                style: TextStyle(fontSize: 12, color: p.t3),
              ),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: Icon(Icons.create_new_folder_outlined, color: p.teal),
              title: Text('新建文件夹', style: TextStyle(color: p.t1)),
              subtitle: Text(
                '在项目根目录创建',
                style: TextStyle(fontSize: 12, color: p.t3),
              ),
              onTap: () => Navigator.pop(ctx, 'dir'),
            ),
          ],
        ),
      ),
    );
    if (v == 'file') {
      _newDialog(isDir: false);
    } else if (v == 'dir') {
      _newDialog(isDir: true);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('文件'),
        actions: [
          IconButton(
            tooltip: '新建',
            onPressed: ps.current == null ? null : _showNewMenu,
            icon: Icon(Icons.add_rounded, size: 22, color: p.t2),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: () {
              _loaded = false;
              _rootNodes.clear();
              setState(() {});
              _maybeLoad();
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
    if (ps.error != null && !_loaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: p.red, size: 42),
              const SizedBox(height: 12),
              Text(
                ps.error ?? '项目初始化失败',
                style: TextStyle(color: p.t2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: () => ps.init(), child: const Text('重试')),
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
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text('正在准备项目…', style: TextStyle(color: p.t3, fontSize: 13)),
          ],
        ),
      );
    }
    final c = ps.current;
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
                  c == null
                      ? '无项目'
                      : (c.builtin
                            ? '${c.name} ${c.version} · 内置项目'
                            : '${c.name} · ${c.fileCount} 个文件'),
                  style: TextStyle(fontSize: 12.5, color: p.t2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _showNewMenu,
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (_rootNodes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.folder_off_outlined, size: 40, color: p.t4),
                const SizedBox(height: 10),
                Text(
                  '空项目——点右上 + 新建文件',
                  style: TextStyle(fontSize: 13, color: p.t3),
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
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: 28.0 + depth * 22),
            child: Text('（空）', style: TextStyle(fontSize: 12, color: p.t4)),
          ),
        );
      }
    }
    return rows;
  }

  Widget _nodeRow(BuildContext context, _Node n, int depth, Pal p) {
    final accent = Theme.of(context).colorScheme.primary;
    IconData icon;
    Color iconColor;
    if (n.isDir) {
      icon = n.expanded ? Icons.folder_open_rounded : Icons.folder_rounded;
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
        onLongPress: () => _showItemMenu(n),
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
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: p.t4,
                  ),
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
                    fontWeight: n.isDir ? FontWeight.w600 : FontWeight.w400,
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
