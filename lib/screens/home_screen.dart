// PCV · 首页（工作区卡片 / 快捷功能 / 最近打开）
import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import '../editor_screen.dart';
import '../widgets.dart';

class HomeScreen extends StatefulWidget {
  final SettingsModel settings;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenSearch;
  const HomeScreen({
    super.key,
    required this.settings,
    required this.onOpenFiles,
    required this.onOpenSearch,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ws = WorkspaceService.instance;

  @override
  void initState() {
    super.initState();
    ws.addListener(_onWs);
  }

  @override
  void dispose() {
    ws.removeListener(_onWs);
    super.dispose();
  }

  void _onWs() {
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
          _workspaceCard(context),
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

  Widget _workspaceCard(BuildContext context) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    final ready = ws.phase == WPhase.ready;

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
                        '源码工作区',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: p.t1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ready
                            ? 'LINGOS ${ws.meta['version'] ?? ''} · '
                                '${ws.meta['file_count'] ?? 0} 个文件 · '
                                '${fmtBytes((ws.meta['byte_count'] as int?) ?? 0)}'
                            : ws.phase == WPhase.error
                                ? '初始化失败'
                                : '正在准备…',
                        style: TextStyle(fontSize: 12, color: p.t3),
                      ),
                    ],
                  ),
                ),
                _wsStatus(context, ready),
              ],
            ),
            const SizedBox(height: 14),
            if (!ready && ws.phase != WPhase.error) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ws.phase == WPhase.unpacking ? ws.progress : null,
                  minHeight: 5,
                  backgroundColor: p.border,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ws.phase == WPhase.unpacking
                    ? '正在解压内置源码… ${(ws.progress * 100).toStringAsFixed(0)}%'
                    : '正在检查内置源码…',
                style: TextStyle(fontSize: 12, color: p.t3),
              ),
            ],
            if (ws.phase == WPhase.error) ...[
              Text(
                ws.error ?? '未知错误',
                style: TextStyle(fontSize: 12, color: p.red),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ws.ensure(force: true),
                child: const Text('重试'),
              ),
            ],
            if (ready) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onOpenFiles,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('浏览源码'),
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
                      onPressed: widget.onOpenSearch,
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('搜索代码'),
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

  Widget _wsStatus(BuildContext context, bool ready) {
    final p = palOf(context);
    if (ws.phase == WPhase.error) {
      return Pill(text: '异常', fg: p.red, bg: tintOf(p.red, p.dark));
    }
    if (!ready) {
      return Pill(text: '准备中', fg: p.yellow, bg: tintOf(p.yellow, p.dark));
    }
    return Pill(
      text: '● 已就绪',
      fg: p.green,
      bg: tintOf(p.green, p.dark),
    );
  }

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
        desc: '解释代码 · 辅助编写',
        tag: '规划中',
        tagColor: p.t3,
        onTap: () => _soon(context, 'AI 助手'),
      ),
      _Quick(
        icon: Icons.fact_check_outlined,
        color: p.yellow,
        title: '检查',
        desc: '语法与问题体检',
        tag: '规划中',
        tagColor: p.t3,
        onTap: () => _soon(context, '代码检查'),
      ),
      _Quick(
        icon: Icons.sync_alt_rounded,
        color: p.cyan,
        title: '连接设备',
        desc: '构建 · 部署 · 回滚',
        tag: '规划中',
        tagColor: p.t3,
        onTap: () => _soon(context, '设备连接与部署'),
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
        children: [
          for (final it in items) _QuickCard(it: it),
        ],
      ),
    );
  }

  void _soon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name：将在后续版本提供（A3/A4/A5 阶段）')),
    );
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
          if (ws.src == null) return;
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
