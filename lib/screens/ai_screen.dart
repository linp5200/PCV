// PCV · AI 助手屏（双模式——先生定义）
//   帮助模式（help）：只读。AI 只能阅读/浏览/解释代码，不允许修改。——适合免费小模型
//   编写模式（write）：可读写。AI 根据需求读取/建议修改代码（编写模式预留部署链接口 A4）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class AiMessage {
  final String role; // user | assistant
  String content;
  AiMessage(this.role, this.content);
}

class AiScreen extends StatefulWidget {
  final SettingsModel settings;
  final VoidCallback onOpenSettings;
  const AiScreen({
    super.key,
    required this.settings,
    required this.onOpenSettings,
  });

  @override
  State<AiScreen> createState() => AiScreenState();
}

class AiScreenState extends State<AiScreen> {
  final ps = ProjectsService.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AiMessage>[];
  final _contextFiles = <String>[];

  bool _sending = false;
  String? _err;

  String get _mode => widget.settings.aiMode;

  bool get _configured => _mode == 'help'
      ? widget.settings.helpConfigured
      : widget.settings.writeConfigured;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- 上下文文件 ----------

  Future<void> _pickContext() async {
    final p = palOf(context);
    final recent = widget.settings.recent;
    if (recent.isEmpty) {
      _toast('最近没有打开过文件——先去文件屏打开一个');
      return;
    }
    final chosen = await showModalBottomSheet<String>(
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Row(
                children: [
                  Text('选择上下文文件', style: TextStyle(fontSize: 14, color: p.t1)),
                ],
              ),
            ),
            for (final r in recent)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: p.t2,
                ),
                title: Text(
                  r,
                  style: TextStyle(fontSize: 13, color: p.t2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && !_contextFiles.contains(chosen)) {
      setState(() => _contextFiles.add(chosen));
    }
  }

  // ---------- 发送 ----------

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!_configured) {
      _toast('请先在设置中配置 AI（${_mode == 'help' ? '帮助' : '编写'}模式）');
      widget.onOpenSettings();
      return;
    }
    setState(() {
      _messages.add(AiMessage('user', text));
      _sending = true;
      _err = null;
      _input.clear();
    });
    _scrollDown();

    try {
      // 组装上下文
      final ctx = StringBuffer();
      final dir = ps.currentDir;
      if (dir != null) {
        final files = <String>{..._contextFiles};
        // 帮助模式自动附带最近打开文件（先生可关）
        if (files.isEmpty && widget.settings.aiAutoContext) {
          files.addAll(widget.settings.recent.take(2));
        }
        for (final rel in files) {
          final content = await readFileForAi(
            dir,
            rel,
            maxChars: _mode == 'help' ? 20000 : 24000,
          );
          ctx.writeln('### 文件：$rel');
          ctx.writeln('```');
          ctx.writeln(content);
          ctx.writeln('```');
          ctx.writeln();
        }
      }

      final projectName = ps.current?.name ?? '';
      final sysReadonly =
          '你是 PCV 代码工作台的 AI 助手（帮助模式·只读）。\n'
          '当前项目：$projectName。\n'
          '规则：\n'
          '1. 你只能阅读、解释、总结代码——绝不提供修改后的完整代码，不输出"替换后"的代码块。\n'
          '2. 解释要具体：引用函数名、行号、调用关系。\n'
          '3. 用户若要求你改代码，请说明切换到"编写模式"才能修改。\n'
          '4. 保持简洁、准确。若信息不足以回答，直接说明缺少什么。';
      final sysWrite =
          '你是 PCV 代码工作台的 AI 助手（编写模式）。\n'
          '当前项目：$projectName。\n'
          '规则：\n'
          '1. 你可以阅读代码并提出修改建议。\n'
          '2. 当你给出修改时，用 ```语言 代码块输出【修改后的完整文件内容】，并在代码块前注明"文件：<相对路径>"。\n'
          '3. 修改要最小化——只改必要部分，保留原有风格。\n'
          '4. 输出前自我检查：语法正确、边界处理、不引入明显 bug。';

      final msgs = <AiMessage>[
        AiMessage('system', _mode == 'help' ? sysReadonly : sysWrite),
      ];
      if (ctx.isNotEmpty) {
        msgs.add(AiMessage('user', '以下是相关文件内容，供你参考：\n$ctx'));
      }
      // 历史（最多 8 条）
      for (final m
          in _messages.length > 8
              ? _messages.sublist(_messages.length - 8)
              : _messages) {
        msgs.add(AiMessage(m.role, m.content));
      }

      final endpoint = _mode == 'help'
          ? widget.settings.helpEndpoint
          : widget.settings.writeEndpoint;
      final apiKey = _mode == 'help'
          ? widget.settings.helpApiKey
          : widget.settings.writeApiKey;
      final model = _mode == 'help'
          ? widget.settings.helpModel
          : widget.settings.writeModel;

      final reply = await AiClient.chat(
        endpoint: endpoint,
        apiKey: apiKey,
        model: model,
        messages: msgs,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(AiMessage('assistant', reply));
        _sending = false;
      });
      _scrollDown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _err = '$e';
      });
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // 从 AI 回复中提取代码块（编写模式用）
  List<(String?, String)> _extractCodeBlocks(String text) {
    final blocks = <(String?, String)>[];
    final lines = text.split('\n');
    String? pendingFile;
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.startsWith('文件：') || line.startsWith('文件:')) {
        pendingFile = line.substring(3).trim();
      }
      if (line.trim().startsWith('```')) {
        final lang = line.trim().substring(3).trim();
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        blocks.add((pendingFile, buf.join('\n')));
        pendingFile = null;
      }
      i++;
    }
    return blocks;
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已复制到剪贴板');
  }

  Future<void> _applyBlock(String? file, String code) async {
    if (_mode != 'write') {
      _toast('帮助模式下不可写入——切换到编写模式');
      return;
    }
    final root = ps.currentDir;
    if (root == null) {
      _toast('项目未就绪');
      return;
    }
    var rel = file;
    rel ??= _contextFiles.isNotEmpty ? _contextFiles.first : null;
    if (rel == null) {
      _toast('请先附加一个上下文文件（或让 AI 注明"文件：路径"）');
      return;
    }
    rel = rel.replaceAll(RegExp(r'^[\./]+'), '');
    final p = palOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('写入文件？', style: TextStyle(fontSize: 16, color: p.t1)),
        content: Text(
          '将用 AI 的代码覆盖：\n$rel\n\n（原内容可在文件屏查看历史；建议先确认代码无误）',
          style: TextStyle(fontSize: 13.5, color: p.t2, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('写入'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final f = File('${root.path}/$rel');
      await f.create(recursive: true);
      await f.writeAsString(code, flush: true);
      ps.refreshFileCount();
      _toast('已写入 $rel');
      widget.settings.touchRecent(rel);
    } catch (e) {
      _toast('写入失败：$e');
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: widget.onOpenSettings,
            icon: Icon(Icons.settings_outlined, size: 20, color: p.t2),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          _modeBar(context, p, accent),
          if (!_configured) _setupHint(context, p, accent),
          Expanded(child: _messageList(context, p, accent)),
          if (_err != null) _errBar(context, p),
          _composer(context, p, accent),
        ],
      ),
    );
  }

  Widget _modeBar(BuildContext context, Pal p, Color accent) {
    Widget chip(String label, String value, String desc, IconData icon) {
      final sel = _mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_mode == value) return;
            widget.settings.setAiMode(value);
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            decoration: BoxDecoration(
              color: sel ? tintOf(accent, p.dark) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? accent.withValues(alpha: .55) : p.border,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 17, color: sel ? accent : p.t3),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? accent : p.t2,
                  ),
                ),
                Text(desc, style: TextStyle(fontSize: 10, color: p.t4)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          chip('帮助', 'help', '只读·理解', Icons.menu_book_outlined),
          chip('编写', 'write', '读改·部署', Icons.edit_note_outlined),
        ],
      ),
    );
  }

  Widget _setupHint(BuildContext context, Pal p, Color accent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_outlined, size: 18, color: p.yellow),
              const SizedBox(width: 8),
              Text(
                '未配置 AI',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: p.t1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _mode == 'help'
                ? '帮助模式为只读——只需一个轻量模型（可接免费服务）。'
                : '编写模式需要能力较强的模型（会读取并建议修改代码）。',
            style: TextStyle(fontSize: 12.5, color: p.t3, height: 1.5),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: widget.onOpenSettings,
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  Widget _messageList(BuildContext context, Pal p, Color accent) {
    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
        children: [
          Icon(Icons.auto_awesome_outlined, size: 46, color: p.t4),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _mode == 'help' ? '问问代码的事' : '说说你想改什么',
              style: TextStyle(fontSize: 15, color: p.t2),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _mode == 'help'
                  ? '例如：这个模块做什么？get_skill_risk 在哪里被调用？'
                  : '例如：给 md5.py 加一个 sha256 函数',
              style: TextStyle(fontSize: 12.5, color: p.t4, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) {
          return _thinking(context, p, accent);
        }
        final m = _messages[i];
        return m.role == 'user'
            ? _userBubble(context, p, accent, m.content)
            : _aiBubble(context, p, accent, m.content);
      },
    );
  }

  Widget _thinking(BuildContext context, Pal p, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
          const SizedBox(width: 10),
          Text('思考中…', style: TextStyle(fontSize: 12.5, color: p.t3)),
        ],
      ),
    );
  }

  Widget _userBubble(BuildContext context, Pal p, Color accent, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, left: 40),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
        decoration: BoxDecoration(
          color: tintOf(accent, p.dark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: .28)),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13.5, color: p.t1, height: 1.5),
        ),
      ),
    );
  }

  Widget _aiBubble(BuildContext context, Pal p, Color accent, String text) {
    final blocks = _extractCodeBlocks(text);
    // 无代码块时直接渲染文本
    if (blocks.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8, right: 30),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: SelectableText(
          text,
          style: TextStyle(fontSize: 13.5, color: p.t1, height: 1.55),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 8, right: 12),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: TextStyle(fontSize: 13.5, color: p.t1, height: 1.55),
            maxLines: 200,
          ),
          const SizedBox(height: 8),
          for (final (file, code) in blocks)
            _codeBlock(context, p, accent, file, code),
        ],
      ),
    );
  }

  Widget _codeBlock(
    BuildContext context,
    Pal p,
    Color accent,
    String? file,
    String code,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: p.dark ? const Color(0xFF1B1E2D) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (file != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 13, color: p.teal),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      file,
                      style: TextStyle(fontSize: 11.5, color: p.teal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              child: SelectableText(
                code,
                style: monoStyle(size: 11.5, color: p.t1, height: 1.5),
              ),
            ),
          ),
          Container(height: 1, color: p.border),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _copy(code),
                icon: Icon(Icons.copy_rounded, size: 15, color: p.t2),
                label: Text('复制', style: TextStyle(fontSize: 12, color: p.t2)),
              ),
              const Spacer(),
              if (_mode == 'write')
                TextButton.icon(
                  onPressed: () => _applyBlock(file, code),
                  icon: Icon(Icons.save_alt_rounded, size: 16, color: accent),
                  label: Text(
                    '写入文件',
                    style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errBar(BuildContext context, Pal p) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tintOf(p.red, p.dark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.red.withValues(alpha: .4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: p.red),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              _err!,
              style: TextStyle(fontSize: 12, color: p.red, height: 1.4),
              maxLines: 4,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: p.red),
            onPressed: () => setState(() => _err = null),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, Pal p, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_contextFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in _contextFiles)
                      Chip(
                        label: Text(
                          f.split('/').last,
                          style: TextStyle(fontSize: 11, color: p.t1),
                        ),
                        backgroundColor: p.elev,
                        side: BorderSide(color: p.border),
                        deleteIcon: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: p.t3,
                        ),
                        onDeleted: () =>
                            setState(() => _contextFiles.remove(f)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '添加上下文文件',
                    onPressed: _pickContext,
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: 21,
                      color: p.t3,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(fontSize: 14, color: p.t1),
                      decoration: InputDecoration(
                        hintText: _mode == 'help' ? '问点什么…' : '要改什么…',
                        hintStyle: TextStyle(color: p.t4, fontSize: 13.5),
                        filled: true,
                        fillColor: p.elev,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: p.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: accent, width: 1.3),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: _sending ? p.t4 : Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _sending ? p.border : accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
