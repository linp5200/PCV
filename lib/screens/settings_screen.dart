// PCV · 设置屏（外观 / AI 助手 / 项目 / 关于）
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
          const SectionLabel('AI 助手'),
          PcvCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.menu_book_outlined,
                  iconColor: p.blue,
                  iconBg: tintOf(p.blue, p.dark),
                  title: '帮助模式（只读）',
                  subtitle: widget.settings.helpConfigured
                      ? '${widget.settings.helpModel} @ ${_short(widget.settings.helpEndpoint)}'
                      : '未配置——点击填写（可用免费轻量模型）',
                  onTap: () => _aiDialog(mode: 'help'),
                ),
                const RowDivider(),
                SettingRow(
                  icon: Icons.edit_note_outlined,
                  iconColor: p.purple,
                  iconBg: tintOf(p.purple, p.dark),
                  title: '编写模式（读改+部署）',
                  subtitle: widget.settings.writeConfigured
                      ? '${widget.settings.writeModel} @ ${_short(widget.settings.writeEndpoint)}'
                      : '未配置——点击填写（建议能力较强的模型）',
                  onTap: () => _aiDialog(mode: 'write'),
                ),
                const RowDivider(),
                SettingRow(
                  icon: Icons.attachment_outlined,
                  iconColor: p.teal,
                  iconBg: tintOf(p.teal, p.dark),
                  title: '自动附带上下文',
                  subtitle: '提问时自动带上最近打开的文件内容',
                  trailing: Switch(
                    value: widget.settings.aiAutoContext,
                    onChanged: (v) =>
                        widget.settings.setAiConfig(aiAutoContext: v),
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('项目'),
          PcvCard(
            padding: EdgeInsets.zero,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.inventory_2_outlined,
                  iconColor: p.green,
                  iconBg: tintOf(p.green, p.dark),
                  title: 'LINGOS 内置源码',
                  subtitle: ps.loaded
                      ? 'v${ps.projects.isNotEmpty && ps.projects.first.builtin ? ps.projects.first.version : ''} · '
                            '${ps.projects.isNotEmpty && ps.projects.first.builtin ? ps.projects.first.fileCount : 0} 个文件'
                      : '正在准备…',
                ),
                const RowDivider(),
                SettingRow(
                  icon: Icons.restart_alt_rounded,
                  iconColor: p.red,
                  iconBg: tintOf(p.red, p.dark),
                  title: '恢复内置源码',
                  subtitle: '重新解压内置包（自建项目不受影响）',
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
                  subtitle: 'PCV 0.2.0 (2) · 多项目 + 文件管理 + AI 助手 + 语法检查',
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

  String _short(String s) =>
      s.length > 34 ? '…${s.substring(s.length - 34)}' : s;

  // ---------- AI 配置 ----------

  Future<void> _aiDialog({required String mode}) async {
    final p = palOf(context);
    final isHelp = mode == 'help';
    final endpointCtrl = TextEditingController(
      text: isHelp
          ? widget.settings.helpEndpoint
          : widget.settings.writeEndpoint,
    );
    final keyCtrl = TextEditingController(
      text: isHelp ? widget.settings.helpApiKey : widget.settings.writeApiKey,
    );
    final modelCtrl = TextEditingController(
      text: isHelp ? widget.settings.helpModel : widget.settings.writeModel,
    );
    var obscure = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: p.elev,
          title: Row(
            children: [
              Icon(
                isHelp ? Icons.menu_book_outlined : Icons.edit_note_outlined,
                size: 20,
                color: isHelp ? p.blue : p.purple,
              ),
              const SizedBox(width: 8),
              Text(
                isHelp ? '配置帮助模式' : '配置编写模式',
                style: TextStyle(fontSize: 16, color: p.t1),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHelp
                      ? '只读助手——解释与总结代码。可用免费的 OpenAI 兼容服务。'
                      : '编写助手——读取并建议修改代码（后续接入部署）。建议用较强模型。',
                  style: TextStyle(fontSize: 12.5, color: p.t3, height: 1.5),
                ),
                const SizedBox(height: 14),
                _dialogField(
                  ctx,
                  '接口地址（OpenAI 兼容）',
                  endpointCtrl,
                  'https://api.example.com/v1',
                ),
                const SizedBox(height: 10),
                _dialogField(
                  ctx,
                  'API Key',
                  keyCtrl,
                  'sk-…',
                  obscure: obscure,
                  suffix: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: p.t3,
                    ),
                    onPressed: () => setD(() => obscure = !obscure),
                  ),
                ),
                const SizedBox(height: 10),
                _dialogField(
                  ctx,
                  '模型名',
                  modelCtrl,
                  'gpt-4o-mini / deepseek-chat / …',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                widget.settings.setAiConfig(
                  helpEndpoint: isHelp ? endpointCtrl.text : null,
                  helpApiKey: isHelp ? keyCtrl.text : null,
                  helpModel: isHelp ? modelCtrl.text : null,
                  writeEndpoint: !isHelp ? endpointCtrl.text : null,
                  writeApiKey: !isHelp ? keyCtrl.text : null,
                  writeModel: !isHelp ? modelCtrl.text : null,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${isHelp ? '帮助' : '编写'}模式配置已保存')),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    BuildContext ctx,
    String label,
    TextEditingController ctrl,
    String hint, {
    bool obscure = false,
    Widget? suffix,
  }) {
    final p = palOf(ctx);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: p.t3)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: TextStyle(fontSize: 13, color: p.t1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.5, color: p.t4),
            suffixIcon: suffix,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ---------- 其它 ----------

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
        title: Text('恢复内置源码？', style: TextStyle(fontSize: 16, color: p.t1)),
        content: Text(
          '将重新解压内置 LINGOS 源码，覆盖内置项目中的修改。\n自建项目完全不受影响。',
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
      await ps.restoreBuiltin();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('内置源码已恢复')));
    }
  }
}
