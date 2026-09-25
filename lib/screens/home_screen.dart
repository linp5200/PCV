// PCV · 首页（项目卡片 / 快捷功能 / 最近打开）
import 'package:flutter/material.dart';

import '../editor_screen.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class HomeScreen extends StatefulWidget {
  final SettingsModel settings;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenAi;
  const HomeScreen({
    super.key,
    required this.settings,
    required this.onOpenFiles,
    required this.onOpenSearch,
    required this.onOpenAi,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ps = ProjectsService.instance;

  @override
  void initState() {
    super.initState();
    ps.addListener(_onPs);
  }

  @override
  void dispose() {
    ps.removeListener(_onPs);
    super.dispose();
  }

  void _onPs() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('代码工作台')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _projectCard(context),
          const SectionLabel('常用功能'),
          _quickGrid(context),
          if (widget.settings.recent.isNotEmpty) ...[
            const SectionLabel('最近打开'),
            _recentCard(context),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              'PCV · Portable Code Visual Workbench',
              style: TextStyle(
                fontSize: 11,
                color: palOf(context).t4,
                letterSpacing: .4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectCard(BuildContext context) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    final ready = ps.loaded && ps.current != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: PcvCard(
        onTap: ready ? widget.onOpenFiles : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: Icons.folder_special_outlined,
                  fg: accent,
                  bg: tintOf(accent, p.dark),
                  size: 38,
                  iconSize: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ps.current?.name ?? '项目',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: p.t1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ready
                            ? (ps.current!.builtin
                                  ? 'LINGOS ${ps.current!.version} · ${ps.current!.fileCount} 个文件 · 内置'
                                  : '${ps.current!.fileCount} 个文件 · 自建项目')
                            : ps.error != null
                            ? '初始化失败'
                            : '正在准备…',
                        style: TextStyle(fontSize: 12, color: p.t3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _wsStatus(context),
              ],
            ),
            if (ps.unpacking) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ps.progress,
                  minHeight: 5,
                  backgroundColor: p.border,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '正在解压内置源码… ${(ps.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: p.t3),
              ),
            ],
            if (ps.error != null) ...[
              const SizedBox(height: 10),
              Text(
                ps.error!,
                style: TextStyle(fontSize: 12, color: p.red),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (ready) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onOpenFiles,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('浏览代码'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showProjectSwitcher,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('切换项目'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: p.border2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _wsStatus(BuildContext context) {
    final p = palOf(context);
    if (ps.error != null) {
      return Pill(text: '异常', fg: p.red, bg: tintOf(p.red, p.dark));
    }
    if (!ps.loaded || ps.unpacking) {
      return Pill(text: '准备中', fg: p.yellow, bg: tintOf(p.yellow, p.dark));
    }
    return Pill(text: '● 已就绪', fg: p.green, bg: tintOf(p.green, p.dark));
  }

  // ---------- 项目切换 ----------

  void _showProjectSwitcher() {
    final p = palOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.elev,
      isScrollControlled: true,
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
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: p.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Row(
                children: [
                  Text(
                    '选择项目',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.t1,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _createProjectDialog();
                    },
                    icon: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    label: Text(
                      '新建项目',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [for (final proj in ps.projects) _projectRow(proj)],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _projectRow(Project proj) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    final sel = proj.id == ps.currentId;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ps.switchTo(proj.id);
          Navigator.pop(context);
          // 最近打开列表按项目隔离——切换时清空
          widget.settings.clearRecent();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? tintOf(accent, p.dark) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? accent.withValues(alpha: .45) : p.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                proj.builtin
                    ? Icons.inventory_2_outlined
                    : Icons.folder_outlined,
                size: 19,
                color: sel ? accent : p.t2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proj.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: p.t1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      proj.builtin
                          ? 'LINGOS ${proj.version} · ${proj.fileCount} 个文件'
                          : '${proj.fileCount} 个文件',
                      style: TextStyle(fontSize: 11.5, color: p.t3),
                    ),
                  ],
                ),
              ),
              if (sel)
                Icon(Icons.check_circle_rounded, size: 18, color: accent),
              if (!proj.builtin && !sel)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: p.t3,
                  ),
                  onPressed: () => _deleteProject(proj),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProjectDialog() async {
    final p = palOf(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('新建项目', style: TextStyle(fontSize: 16, color: p.t1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: p.t1),
          decoration: InputDecoration(
            hintText: '项目名称（如：我的工具）',
            hintStyle: TextStyle(color: p.t4, fontSize: 13.5),
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
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final proj = await ps.createProject(name);
    ps.switchTo(proj.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('项目「$name」已创建')));
    }
  }

  Future<void> _deleteProject(Project proj) async {
    final p = palOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text(
          '删除项目「${proj.name}」？',
          style: TextStyle(fontSize: 16, color: p.t1),
        ),
        content: Text(
          '将删除该项目的全部文件（不可撤销）。',
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
    if (ok == true) {
      await ps.deleteProject(proj.id);
    }
  }

  // ---------- 快捷功能 ----------

  Widget _quickGrid(BuildContext context) {
    final p = palOf(context);
    final items = <_Quick>[
      _Quick(
        icon: Icons.search_rounded,
        color: p.blue,
        title: '搜索',
        desc: '全库查找符号与文本',
        tag: '立即可用',
        tagColor: p.green,
        onTap: widget.onOpenSearch,
      ),
      _Quick(
        icon: Icons.auto_awesome_outlined,
        color: p.purple,
        title: 'AI 助手',
        desc: '帮助（只读）· 编写（读改）',
        tag: '已可用',
        tagColor: p.green,
        onTap: widget.onOpenAi,
      ),
      _Quick(
        icon: Icons.fact_check_outlined,
        color: p.yellow,
        title: '语法检查',
        desc: '编辑器内实时标错',
        tag: '已内置',
        tagColor: p.green,
        onTap: () => _soon(context, '语法检查已内置于编辑器：打开任意文件即自动检查（波浪线 + 行号标记）'),
      ),
      _Quick(
        icon: Icons.sync_alt_rounded,
        color: p.cyan,
        title: '连接设备',
        desc: '构建 · 部署 · 回滚',
        tag: '规划中',
        tagColor: p.t3,
        onTap: () => _soon(context, '设备连接与部署（A4 批次）'),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.42,
        children: [for (final it in items) _QuickCard(it: it)],
      ),
    );
  }

  void _soon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(name)));
  }

  Widget _recentCard(BuildContext context) {
    final p = palOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PcvCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < widget.settings.recent.length; i++) ...[
              if (i > 0) const RowDivider(indent: 16),
              _recentRow(context, widget.settings.recent[i], p),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recentRow(BuildContext context, String rel, Pal p) {
    final style = fileStyleFor(rel, p);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (ps.currentDir == null) return;
          widget.settings.touchRecent(rel);
          await EditorScreen.open(context, widget.settings, rel);
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(style.$1, size: 17, color: style.$2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rel,
                  style: TextStyle(fontSize: 13, color: p.t1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 17, color: p.t4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Quick {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;
  const _Quick({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.tag,
    required this.tagColor,
    required this.onTap,
  });
}

class _QuickCard extends StatelessWidget {
  final _Quick it;
  const _QuickCard({required this.it});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return PcvCard(
      onTap: it.onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: it.icon,
                fg: it.color,
                bg: tintOf(it.color, p.dark),
                size: 32,
                iconSize: 16,
              ),
              const Spacer(),
              Pill(
                text: it.tag,
                fg: it.tagColor,
                bg: it.tagColor.withValues(alpha: p.dark ? .12 : .10),
                fontSize: 10.5,
              ),
            ],
          ),
          const Spacer(),
          Text(
            it.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: p.t1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            it.desc,
            style: TextStyle(fontSize: 11.5, color: p.t3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
