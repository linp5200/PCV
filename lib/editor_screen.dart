// PCV · 编辑器屏（WebView + CodeMirror 6 成熟内核）
// 高亮/折叠/搜索/括号匹配 = CodeMirror 6；本页只做桥接与草稿
// WebView 宿主 = 官方 webview_flutter 插件（Flutter 团队维护）
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

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
  static File? _htmlFileCache;

  WebViewController? _web;
  bool _pageReady = false;
  bool _readySent = false;
  bool _leaving = false;
  bool _dirty = false;
  bool _draftRestored = false;
  bool _hasDraft = false;

  int _lines = 0;
  int _line = 1;
  int _col = 1;

  String? _loadError;
  String? _pendingContent;
  Timer? _draftTimer;

  // ---------- 路径 ----------

  String get _rel => widget.rel;

  File get _srcFile => File('${WorkspaceService.instance.src!.path}/$_rel');

  Future<File> _draftFile() async {
    final root = WorkspaceService.instance.root!.parent.path;
    final d = Directory('$root/drafts');
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

  @override
  void dispose() {
    _draftTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (WorkspaceService.instance.src == null) {
        throw Exception('工作区未就绪');
      }
      final f = _srcFile;
      if (!await f.exists()) throw Exception('文件不存在：$_rel');
      var content = await f.readAsString();
      final df = await _draftFile();
      if (await df.exists()) {
        content = await df.readAsString();
        _draftRestored = true;
        _hasDraft = true;
      }
      _pendingContent = content;
    } catch (e) {
      _loadError = '$e';
    }
    if (mounted) setState(() {});
    // 两种时序都覆盖：①内容先到、页面后到（ready 事件触发）②页面先就绪、内容后到（此处触发）
    _bootWebView();
  }

  Future<String> _editorHtml() async {
    if (_htmlCache != null) return _htmlCache!;
    _htmlCache = await rootBundle.loadString('assets/webview/editor.html');
    return _htmlCache!;
  }

  /// 把内核 HTML 落到本地文件（跨屏复用——loadFile 比 loadHtmlString 更省通道）
  Future<File> _htmlFile() async {
    final cached = _htmlFileCache;
    if (cached != null && await cached.exists()) return cached;
    final html = await _editorHtml();
    final docs = await getApplicationDocumentsDirectory();
    final f = File('${docs.path}/pcv/editor.html');
    await f.create(recursive: true);
    final expected = utf8.encode(html).length;
    if (!await f.exists() || (await f.length()) != expected) {
      await f.writeAsString(html, flush: true);
    }
    _htmlFileCache = f;
    return f;
  }

  Future<WebViewController> _ensureController() async {
    final existing = _web;
    if (existing != null) return existing;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1F2335))
      ..addJavaScriptChannel(
        'PcvBridge',
        onMessageReceived: (msg) {
          try {
            final m = jsonDecode(msg.message);
            if (m is Map) {
              _onJsEvent(m['type']?.toString() ?? '', m['payload']);
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) => NavigationDecision.prevent,
        ),
      );
    _web = c;
    try {
      final f = await _htmlFile();
      await c.loadFile(f.path);
    } catch (_) {
      try {
        final html = await _editorHtml();
        await c.loadHtmlString(html);
      } catch (_) {}
    }
    return c;
  }

  Future<void> _bootWebView() async {
    if (!_pageReady || _readySent) return;
    final content = _pendingContent;
    if (content == null) return;
    _readySent = true;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final js =
        'window.pcv.openFile('
        '${jsonEncode(_rel)}, ${jsonEncode(content)}, '
        '{"dark": $dark, "fontPx": ${widget.settings.codeFontSize}});';
    try {
      await _web?.runJavaScript(js);
      if (widget.jumpToLine != null && widget.jumpToLine! > 1) {
        await _web?.runJavaScript('window.pcv.goToLine(${widget.jumpToLine});');
      }
      if (_draftRestored && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已恢复上次自动保存的草稿')));
      }
    } catch (_) {}
  }

  // ---------- JS 事件 ----------

  void _onJsEvent(String type, dynamic payload) {
    if (!mounted) return;
    switch (type) {
      case 'ready':
        _pageReady = true;
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
        if (payload is Map) {
          final lines = (payload['lines'] as num?)?.toInt();
          if (lines != null) _lines = lines;
        }
        _setDirty(true);
        _scheduleDraftSave();
        break;
    }
  }

  void _setDirty(bool v) {
    if (_dirty != v && mounted) setState(() => _dirty = v);
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 1200), () async {
      final c = await _grabContent();
      if (c != null) {
        await _saveDraft(c);
        _setDirty(false);
      }
    });
  }

  Future<void> _saveDraft(String content) async {
    try {
      final df = await _draftFile();
      await df.writeAsString(content, flush: false);
      _hasDraft = true;
    } catch (_) {}
  }

  /// 拉取当前内容（编辑不中断——结束时保存，防止最后输入丢失）
  Future<String?> _grabContent() async {
    try {
      final r = await _web?.runJavaScriptReturningResult(
        'window.pcv.getContent()',
      );
      if (r == null) return null;
      if (r is String) {
        if (r == 'null') return null;
        // Android 端结果为 JSON 序列化字符串（引号包裹 + 转义）
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

  Future<void> _saveNow() async {
    final c = await _grabContent();
    if (c != null) {
      await _saveDraft(c);
      _setDirty(false);
    }
  }

  Future<void> _handleBack() async {
    if (_leaving) return;
    await _saveNow();
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
                '丢弃本文件草稿，回到内置源码',
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
        title: Text('恢复原版内容？', style: TextStyle(fontSize: 16, color: p.t1)),
        content: Text(
          '将丢弃本文件的所有未保存修改（草稿），恢复为内置源码内容。',
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
      if (await df.exists()) await df.delete();
      final content = await _srcFile.readAsString();
      final dark = Theme.of(context).brightness == Brightness.dark;
      await _web?.runJavaScript(
        'window.pcv.openFile('
        '${jsonEncode(_rel)}, ${jsonEncode(content)}, '
        '{"dark": $dark, "fontPx": ${widget.settings.codeFontSize}});',
      );
      if (mounted) {
        setState(() {
          _dirty = false;
          _hasDraft = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已恢复为内置原版内容')));
      }
    } catch (_) {}
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
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
              if (_hasDraft)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Pill(
                    text: '草稿',
                    fg: p.cyan,
                    bg: tintOf(p.cyan, p.dark),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          actions: [
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
    return FutureBuilder<WebViewController>(
      future: _ensureController(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        return WebViewWidget(controller: snap.data!);
      },
    );
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
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                size: 14,
                color: _dirty ? p.yellow : p.green,
              ),
              const SizedBox(width: 5),
              Text(
                _dirty ? '草稿保存中…' : '草稿已保存',
                style: TextStyle(fontSize: 11, color: p.t3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
