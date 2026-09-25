// PCV · 设置屏（外观 / 内置源码包 / 关于）
import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsModel settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    final p = palOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SectionLabel('外观'),
          PcvCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Icon(Icons.contrast_rounded, size: 18, color: p.t2),
                      const SizedBox(width: 10),
                      Text('主题', style: TextStyle(fontSize: 14, color: p.t1)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _themeChip('跟随系统', 'system'),
                      const SizedBox(width: 8),
                      _themeChip('暗色', 'dark'),
                      const SizedBox(width: 8),
                      _themeChip('亮色', 'light'),
                    ],
                  ),
                ),
                const RowDivider(indent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 18, color: p.t2),
                      const SizedBox(width: 10),
                      Text('强调色', style: TextStyle(fontSize: 14, color: p.t1)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Row(
                    children: [
                      for (final a in accentPresets) ...[
                        _accentDot(a),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
                const RowDivider(indent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.format_size_rounded, size: 18, color: p.t2),
                      const SizedBox(width: 10),
                      Text('代码字号', style: TextStyle(fontSize: 14, color: p.t1)),
                      const Spacer(),
                      Text(
                        '${widget.settings.codeFontSize.toStringAsFixed(0)} px',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Slider(
                    value: widget.settings.codeFontSize,
                    min: 11,
                    max: 20,
                    divisions: 9,
                    onChanged: (v) => widget.settings.setCodeFontSize(v),
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('内置源码包'),
          PcvCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: p.blue,
                  iconBg: tintOf(p.blue, p.dark),
                  title: 'LINGOS 源码',
                  subtitle: ws.phase == WPhase.ready
                      ? 'v${ws.meta['version'] ?? ''} · ${ws.meta['file_count'] ?? 0} 个文件'
                      : ws.phase == WPhase.error
                      ? '初始化失败'
                      : '正在准备…',
                ),
                const RowDivider(),
                SettingRow(
                  icon: Icons.schedule_rounded,
                  iconColor: p.teal,
                  iconBg: tintOf(p.teal, p.dark),
                  title: '打包时间',
                  subtitle: '${ws.meta['built_at'] ?? '—'}',
                ),
                const RowDivider(),
                SettingRow(
                  icon: Icons.commit_rounded,
                  iconColor: p.purple,
                  iconBg: tintOf(p.purple, p.dark),
                  title: '提交',
                  subtitle: (ws.meta['commit'] as String? ?? '').isNotEmpty
                      ? (ws.meta['commit'] as String).substring(0, 7)
                      : '—',
                ),
                const RowDivider(),
                SettingRow(
                  icon: Icons.restart_alt_rounded,
                  iconColor: p.red,
                  iconBg: tintOf(p.red, p.dark),
                  title: '恢复原版源码',
                  subtitle: '重新解压内置包（编辑内容与草稿保留）',
                  titleColor: p.red,
                  onTap: _confirmRestore,
                ),
              ],
            ),
          ),
          const SectionLabel('关于'),
          PcvCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: p.t2,
                  iconBg: p.dark ? p.hover : p.root,
                  title: '版本',
                  subtitle: 'PCV 0.1.0 (1) · A1 骨架 + 内置源码 + 编辑器',
                ),
                const RowDivider(),
                SettingRow(
                  icon: Icons.article_outlined,
                  iconColor: p.t2,
                  iconBg: p.dark ? p.hover : p.root,
                  title: '开源许可',
                  subtitle: 'Flutter · CodeMirror 6 · JetBrains Mono (OFL)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'PCV · Portable Code Visual Workbench\n便携代码图形化工作台',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: p.t4, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeChip(String label, String value) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    final sel = widget.settings.themeMode == value;
    return GestureDetector(
      onTap: () => widget.settings.setThemeMode(value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: sel ? tintOf(accent, p.dark) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: sel ? accent.withValues(alpha: .55) : p.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? accent : p.t2,
          ),
        ),
      ),
    );
  }

  Widget _accentDot(AccentPreset a) {
    final p = palOf(context);
    final sel = widget.settings.accent == a.id;
    final color = p.dark ? a.dark : a.light;
    return GestureDetector(
      onTap: () => widget.settings.setAccent(a.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: sel ? p.t1 : Colors.transparent,
                width: 2,
              ),
            ),
            child: sel
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: p.dark ? const Color(0xFF151A2E) : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            a.name,
            style: TextStyle(
              fontSize: 10.5,
              color: sel ? p.t1 : p.t3,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore() async {
    final p = palOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('恢复原版源码？', style: TextStyle(fontSize: 16, color: p.t1)),
        content: Text(
          '将重新解压内置源码包，覆盖工作区中的源码文件。\n'
          '你的未部署修改若只存在于工作区将被覆盖——草稿区不受影响。',
          style: TextStyle(fontSize: 13.5, color: p.t2, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('恢复', style: TextStyle(color: p.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ws.ensure(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('源码已恢复为内置原版')));
    }
  }
}
