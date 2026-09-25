// PCV · 编辑器屏（WebView + CodeMirror 6 成熟内核）
// 高亮/折叠/搜索/括号匹配/语法检查(lint)/手势 = CM6 生态；本页只做桥接与保存逻辑
//
// 保存模型（先生确认）：
//   · 点击「保存」→ 直接写回源文件（草稿仅作防丢失缓冲，不是主流程）
//   · 有未保存修改才产生草稿；纯浏览不产生草稿
//   · 退出时若有未保存修改 → 询问（保存并退出 / 仅退出 / 取消）
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import 'services.dart';
import 'theme.dart';

class EditorScreen extends StatefulWidget {
  final SettingsModel settings;
  final String rel;
  final int? jumpToLine;
  const EditorScreen({
    super.key,
    required this.settings,
    required this.rel,
    this.jumpToLine,
  });

  static Future<void> open(
    BuildContext context,
    SettingsModel settings,
    String rel, {
    int? jumpToLine,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EditorScreen(settings: settings, rel: rel, jumpToLine: jumpToLine),
      ),
    );
  }

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static String? _htmlCache;

  WebViewController? _web;
  bool _webReady = false;
  bool _fileSent = false;
  bool _leaving = false;
  bool _dirty = false;
  bool _draftRestored = false;
  bool _saving = false;

  int _lines = 0;
  int _line = 1;
  int _col = 1;
  String? _loadError;

  String get _rel => widget.rel;

  Directory? get _root => ProjectsService.instance.currentDir;

  File? get _srcFile {
    final r = _root;
    return r == null ? null : File('${r.path}/$_rel');
  }

  Future<File?> _draftFile() async {
    final r = _root;
    if (r == null) return null;
    final d = Directory('${r.path}/.pcv_drafts');
    await d.create(recursive: true);
    final safe = _rel.replaceAll('/', '__');
    return File('${d.path}/$safe');
  }

  // ---------- 打开流程 ----------

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _pendingContent;

  Future<void> _load() async {
    try {
      final f = _srcFile;
      if (f == null) throw Exception('项目未就绪');
      if (!await f.exists()) throw Exception('文件不存在：$_rel');
      final original = await f.readAsString();
      var content = original;

      // 草稿恢复：仅当草稿与源文件不一致（=存在未保存修改）才恢复；
      // 一致则视为"纯浏览残留"，直接清理（修复"浏览也标草稿"问题）
      final df = await _draftFile();
      if (df != null && await df.exists()) {
        final draft = await df.readAsString();
        if (draft != original) {
          content = draft;
          _draftRestored = true;
          _dirty = true;
        } else {
          try {
            await df.delete();
          } catch (_) {}
        }
      }
      _pendingContent = content;
    } catch (e) {
      _loadError = '$e';
    }
    if (mounted) setState(() {});
    _bootWebView();
  }

  Future<String> _editorHtml() async {
    if (_htmlCache != null) return _htmlCache!;
    _htmlCache = await rootBundle.loadString('assets/webview/editor.html');
    return _htmlCache!;
  }

  Future<void> _bootWebView() async {
    final web = _web;
    final content = _pendingContent;
    if (web == null || !_webReady || _fileSent || content == null) return;
    _fileSent = true;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final js =
        'window.pcv.openFile('
        '${jsonEncode(_rel)}, ${jsonEncode(content)}, '
        '{"dark": $dark, "fontPx": ${widget.settings.codeFontSize}});';
    try {
      await web.runJavaScript(js);
      if (widget.jumpToLine != null && widget.jumpToLine! > 1) {
        await web.runJavaScript('window.pcv.goToLine(${widget.jumpToLine});');
      }
      if (_draftRestored && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已恢复未保存的修改')));
      }
    } catch (_) {}
  }

  // ---------- JS 事件 ----------

  void _onJsEvent(String type, dynamic payload) {
    if (!mounted) return;
    switch (type) {
      case 'ready':
        _webReady = true;
        _bootWebView();
        break;
      case 'fileOpened':
        if (payload is Map) {
          setState(() {
            _lines = (payload['lines'] as num?)?.toInt() ?? 0;
          });
        }
        break;
      case 'cursor':
        if (payload is Map) {
          setState(() {
            _line = (payload['line'] as num?)?.toInt() ?? 1;
            _col = (payload['col'] as num?)?.toInt() ?? 1;
          });
        }
        break;
      case 'changed':
        // 真正有文档变更才到这里（CM6 docChanged）→ 写防丢失草稿
        _setDirty(true);
        _saveDraftSoon();
        break;
      case 'fontChanged':
        if (payload is Map) {
          final px = (payload['fontPx'] as num?)?.toDouble();
          if (px != null) widget.settings.setCodeFontSize(px);
        }
        break;
      case 'indentDone':
        // 缩进已完成——无需处理（可扩展：轻提示）
        break;
    }
  }

  void _setDirty(bool v) {
    if (_dirty != v && mounted) setState(() => _dirty = v);
  }

  // 草稿防丢失（延迟 900ms 拉取，避免频繁跨桥）
  bool _draftTimerActive = false;
  Future<void> _saveDraftSoon() async {
    if (_draftTimerActive) return;
    _draftTimerActive = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _draftTimerActive = false;
    if (!mounted || !_dirty) return;
    final c = await _grabContent();
    if (c == null) return;
    try {
      final df = await _draftFile();
      await df?.writeAsString(c, flush: false);
    } catch (_) {}
  }

  Future<String?> _grabContent() async {
    try {
      final r = await _web?.runJavaScriptReturningResult(
        'window.pcv.getContent()',
      );
      if (r == null) return null;
      if (r is String) {
        if (r == 'null') return null;
        try {
          final decoded = jsonDecode(r);
          if (decoded is String) return decoded;
          if (decoded == null) return null;
        } catch (_) {}
        return r;
      }
      return r.toString();
    } catch (_) {}
    return null;
  }

  // ---------- 保存（核心——直接写文件） ----------

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final c = await _grabContent();
    if (c == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      final f = _srcFile;
      if (f == null) throw Exception('项目未就绪');
      await f.writeAsString(c, flush: true);
      // 源文件已同步 → 清除草稿
      try {
        final df = await _draftFile();
        if (df != null && await df.exists()) await df.delete();
      } catch (_) {}
      _setDirty(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存：$_rel'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  // ---------- 退出（未保存询问） ----------

  Future<void> _handleBack() async {
    if (_leaving) return;
    if (_dirty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('有未保存的修改', style: TextStyle(fontSize: 16)),
          content: const Text(
            '选择「保存并退出」将直接写回源文件；\n选择「仅退出」将保留草稿（下次打开可恢复）。',
            style: TextStyle(fontSize: 13.5, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'draft'),
              child: const Text('仅退出'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('保存并退出'),
            ),
          ],
        ),
      );
      if (choice == 'cancel' || choice == null) return;
      if (choice == 'save') {
        await _save();
      } else {
        // 仅退出：确保草稿已写入（最后时刻的内容）
        final c = await _grabContent();
        if (c != null) {
          try {
            final df = await _draftFile();
            await df?.writeAsString(c, flush: true);
          } catch (_) {}
        }
      }
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ---------- 操作菜单 ----------

  Future<void> _showMenu() async {
    final p = palOf(context);
    final action = await showModalBottomSheet<String>(
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
              leading: Icon(Icons.search_rounded, color: p.blue),
              title: Text('文件内搜索', style: TextStyle(color: p.t1)),
              subtitle: Text(
                'CodeMirror 搜索面板',
                style: TextStyle(fontSize: 12, color: p.t3),
              ),
              onTap: () => Navigator.pop(ctx, 'search'),
            ),
            ListTile(
              leading: Icon(Icons.pin_rounded, color: p.teal),
              title: Text('转到行', style: TextStyle(color: p.t1)),
              onTap: () => Navigator.pop(ctx, 'gotoline'),
            ),
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: p.red),
              title: Text('恢复原版内容', style: TextStyle(color: p.red)),
              subtitle: Text(
                '丢弃本文件未保存修改，回到源文件当前内容',
                style: TextStyle(fontSize: 12, color: p.t3),
              ),
              onTap: () => Navigator.pop(ctx, 'revert'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'search':
        await _web?.runJavaScript("window.pcv.search('');");
        break;
      case 'gotoline':
        await _goToLineDialog();
        break;
      case 'revert':
        await _revert();
        break;
    }
  }

  Future<void> _goToLineDialog() async {
    final p = palOf(context);
    final ctrl = TextEditingController(text: '$_line');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('转到行', style: TextStyle(fontSize: 16, color: p.t1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: p.t1),
          decoration: InputDecoration(
            hintText: '1 – $_lines',
            hintStyle: TextStyle(color: p.t4),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    if (n != null && n >= 1) {
      await _web?.runJavaScript('window.pcv.goToLine($n);');
    }
  }

  Future<void> _revert() async {
    final p = palOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('恢复为源文件内容？', style: TextStyle(fontSize: 16, color: p.t1)),
        content: Text(
          '将丢弃当前未保存的所有修改，恢复为源文件当前版本（已保存的内容不受影响）。',
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
    if (ok != true) return;
    try {
      final df = await _draftFile();
      if (df != null && await df.exists()) await df.delete();
      final content = await _srcFile?.readAsString() ?? '';
      final dark = Theme.of(context).brightness == Brightness.dark;
      await _web?.runJavaScript(
        'window.pcv.openFile('
        '${jsonEncode(_rel)}, ${jsonEncode(content)}, '
        '{"dark": $dark, "fontPx": ${widget.settings.codeFontSize}});',
      );
      _setDirty(false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已恢复为源文件内容')));
      }
    } catch (_) {}
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: p.dark ? const Color(0xFF1F2335) : Colors.white,
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              Flexible(
                child: Text(
                  _rel.split('/').last,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.t1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: p.yellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            // 保存按钮（核心——有修改时高亮可点）
            TextButton.icon(
              onPressed: (_dirty && !_saving) ? _save : null,
              icon: _saving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Icon(
                      Icons.save_rounded,
                      size: 18,
                      color: _dirty ? accent : p.t4,
                    ),
              label: Text(
                '保存',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _dirty ? accent : p.t4,
                ),
              ),
            ),
            IconButton(
              tooltip: '操作',
              onPressed: _showMenu,
              icon: Icon(Icons.more_vert_rounded, size: 20, color: p.t2),
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: p.border),
          ),
        ),
        body: _body(context),
        bottomNavigationBar: _statusBar(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final p = palOf(context);
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 42, color: p.red),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                style: TextStyle(color: p.t2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<String>(
      future: _editorHtml(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        return WebViewWidget(controller: _makeController(snap.data!));
      },
    );
  }

  WebViewController? _controller;
  WebViewController _makeController(String html) {
    if (_controller != null) return _controller!;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1F2335))
      ..addJavaScriptChannel(
        'PcvBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final j = jsonDecode(message.message) as Map<String, dynamic>;
            _onJsEvent(j['type']?.toString() ?? '', j['payload']);
          } catch (_) {}
        },
      )
      ..loadHtmlString(html, baseUrl: 'https://pcv.local/');
    _web = c;
    return c;
  }

  Widget _statusBar(BuildContext context) {
    final p = palOf(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('L$_line : C$_col', style: monoStyle(size: 11, color: p.t3)),
              const SizedBox(width: 14),
              Text('$_lines 行', style: monoStyle(size: 11, color: p.t3)),
              const Spacer(),
              Icon(
                _dirty
                    ? Icons.edit_note_rounded
                    : Icons.check_circle_outline_rounded,
                size: 14,
                color: _dirty ? p.yellow : p.green,
              ),
              const SizedBox(width: 5),
              Text(
                _dirty ? '未保存' : '已保存',
                style: TextStyle(fontSize: 11, color: p.t3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
