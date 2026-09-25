// PCV · 编辑器屏（WebView + CodeMirror 6 成熟内核）
// 高亮/折叠/搜索/括号匹配 = CodeMirror 6；本页只做桥接与草稿
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
        builder: (_) => EditorScreen(
          settings: settings,
          rel: rel,
          jumpToLine: jumpToLine,
        ),
      ),
    );
  }

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static String? _htmlCache;

  InAppWebViewController? _web;
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

  // ---------- 路径 ----------

  String get _rel => widget.rel;

  File get _srcFile =>
      File('${WorkspaceService.instance.src!.path}/$_rel');

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
  }

  String? _pendingContent;

  Future<String> _editorHtml() async {
    if (_htmlCache != null) return _htmlCache!;
    _htmlCache = await rootBundle.loadString('assets/webview/editor.html');
    return _htmlCache!;
  }

  Future<void> _bootWebView() async {
    if (!_pageReady || _readySent) return;
    final content = _pendingContent;
    if (content == null) return;
    _readySent = true;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final js = 'window.pcv.openFile('
        '${jsonEncode(_rel)}, ${jsonEncode(content)}, '
        '{"dark": $dark, "fontPx": ${widget.settings.codeFontSize}});';
    try {
      await _web?.evaluateJavascript(source: js);
      if (widget.jumpToLine != null && widget.jumpToLine! > 1) {
        await _web?.evaluateJavascript(
          source: 'window.pcv.goToLine(${widget.jumpToLine});',
        );
      }
      if (_draftRestored && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复上次自动保存的草稿')),
        );
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
          final content = payload['content'];
          if (content is String) {
            _setDirty(true);
            _saveDraft(content);
          }
        }
        break;
    }
  }

  void _setDirty(bool v) {
    if (_dirty != v && mounted) setState(() => _dirty = v);
  }

  Future<void> _saveDraft(String content) async {
    try {
      final df = await _draftFile();
      await df.writeAsString(content, flush: false);
      _hasDraft = true;
    } catch (_) {}
  }

  /// 取出当前内容（用于退出前保存——防止最后 700ms 内输入丢失）
  Future<String?> _grabContent() async {
    try {
      final r = await _web?.evaluateJavascript(
        source: 'window.pcv.getContentJson()',
      );
      if (r is Map) return r['content'] as String?;
      if (r is String) {
        final m = jsonDecode(r);
        if (m is Map) return m['content'] as String?;
      }
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
              subtitle: Text('CodeMirror 搜索面板',
                  style: TextStyle(fontSize: 12, color: p.t3)),
              onTap: () => Navigator.pop(ctx, 'search'),
            ),
            ListTile(
              leading: Icon(Icons.pin_rounded, color: p.teal),
              title: Text('转到行', style: TextStyle(color: p.t1)),
              onTap: () => Navigator.pop(ctx, 'gotoline'),
            ),
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: p.red),
              title: Text('恢复原版内容',
                  style: TextStyle(color: p.red)),
              subtitle: Text('丢弃本文件草稿，回到内置源码',
                  style: TextStyle(fontSize: 12, color: p.t3)),
              onTap: () => Navigator.pop(ctx, 'revert'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'search':
        await _web?.evaluateJavascript(source: "window.pcv.search('');");
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
          onSubmitted: (v) =>
              Navigator.pop(ctx, int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
                ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    if (n != null && n >= 1) {
      await _web?.evaluateJavascript(source: 'window.pcv.goToLine($n);');
    }
  }

  Future<void> _revert() async {
    final p = palOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.elev,
        title: Text('恢复原版内容？',
            style: TextStyle(fontSize: 16, color: p.t1)),
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
      await _web?.evaluateJavascript(
        source: 'window.pcv.openFile('
            '${jsonEncode(_rel)}, ${jsonEncode(content)}, '
            '{"dark": $dark, "fontPx": ${widget.settings.codeFontSize}});',
      );
      if (mounted) {
        setState(() {
          _dirty = false;
          _hasDraft = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复为内置原版内容')),
        );
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
              Text(_loadError!,
                  style: TextStyle(color: p.t2),
                  textAlign: TextAlign.center),
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
        return InAppWebView(
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            supportZoom: false,
            builtInZoomControls: false,
            displayZoomControls: false,
            disableHorizontalScroll: true,
            transparentBackground: false,
            mediaPlaybackRequiresUserGesture: true,
            useHybridComposition: true,
            allowFileAccess: false,
          ),
          onWebViewCreated: (controller) {
            _web = controller;
            controller.addJavaScriptHandler(
              handlerName: 'pcv',
              callback: (args) {
                if (args.isEmpty) return null;
                _onJsEvent(
                  args[0]?.toString() ?? '',
                  args.length > 1 ? args[1] : null,
                );
                return null;
              },
            );
            controller.loadData(
              data: snap.data!,
              mimeType: 'text/html',
              encoding: 'utf-8',
            );
          },
          onReceivedError: (controller, request, error) {
            // 子资源错误忽略（单文件内联，不应发生）
          },
        );
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
              Text(
                'L$_line : C$_col',
                style: monoStyle(size: 11, color: p.t3),
              ),
              const SizedBox(width: 14),
              Text(
                '$_lines 行',
                style: monoStyle(size: 11, color: p.t3),
              ),
              const Spacer(),
              Icon(
                _dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
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
