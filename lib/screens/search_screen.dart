// PCV · 搜索屏（文件名 / 内容 / 全部）
import 'dart:async';

import 'package:flutter/material.dart';

import '../editor_screen.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class SearchScreen extends StatefulWidget {
  final SettingsModel settings;
  const SearchScreen({super.key, required this.settings});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final ws = WorkspaceService.instance;
  final _controller = TextEditingController();
  Timer? _debounce;

  String _mode = 'all'; // all | name | content
  bool _searching = false;
  SearchOutcome? _outcome;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), _run);
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _outcome = null;
        _searching = false;
      });
      return;
    }
    if (ws.src == null || ws.phase != WPhase.ready) return;
    setState(() => _searching = true);
    final out = await searchWorkspace(
      ws.src!,
      q,
      nameOnly: _mode == 'name',
      contentOnly: _mode == 'content',
    );
    if (!mounted) return;
    setState(() {
      _outcome = out;
      _searching = false;
    });
  }

  Future<void> _openHit(String rel, int line) async {
    widget.settings.touchRecent(rel);
    await EditorScreen.open(context, widget.settings, rel, jumpToLine: line);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: false,
              onChanged: _onChanged,
              onSubmitted: (_) => _run(),
              style: TextStyle(fontSize: 14.5, color: p.t1),
              decoration: InputDecoration(
                hintText: '搜索代码或文件…',
                hintStyle: TextStyle(color: p.t4, fontSize: 14),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 20, color: p.t3),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: p.t3),
                        onPressed: () {
                          _controller.clear();
                          _run();
                        },
                      ),
                filled: true,
                fillColor: p.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accent, width: 1.4),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _modeChip('全部', 'all', p, accent),
                const SizedBox(width: 8),
                _modeChip('文件名', 'name', p, accent),
                const SizedBox(width: 8),
                _modeChip('内容', 'content', p, accent),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _results(context)),
        ],
      ),
    );
  }

  Widget _modeChip(String label, String value, Pal p, Color accent) {
    final sel = _mode == value;
    return GestureDetector(
      onTap: () {
        setState(() => _mode = value);
        _run();
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 13),
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

  Widget _results(BuildContext context) {
    final p = palOf(context);
    if (_searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('搜索中…', style: TextStyle(fontSize: 13, color: p.t3)),
          ],
        ),
      );
    }
    final out = _outcome;
    if (out == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search_rounded, size: 46, color: p.t4),
            const SizedBox(height: 10),
            Text('输入关键词开始搜索',
                style: TextStyle(fontSize: 13.5, color: p.t3)),
            const SizedBox(height: 4),
            Text('全库检索 · 支持文件名与内容',
                style: TextStyle(fontSize: 12, color: p.t4)),
          ],
        ),
      );
    }
    if (out.total == 0 && out.nameHits.isEmpty) {
      return Center(
        child: Text('未找到匹配结果',
            style: TextStyle(fontSize: 13.5, color: p.t3)),
      );
    }
    final rows = <Widget>[];
    rows.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        '共 ${out.total} 处内容匹配 · ${out.groups.length} 个文件'
        '${out.nameHits.isNotEmpty ? ' · ${out.nameHits.length} 个文件名匹配' : ''}'
        '${out.truncated ? ' · 已截断' : ''}',
        style: TextStyle(fontSize: 12, color: p.t3),
      ),
    ));
    if (out.nameHits.isNotEmpty) {
      rows.add(const SectionLabel('文件名匹配'));
      for (final n in out.nameHits) {
        rows.add(_nameRow(context, n, p));
      }
    }
    if (out.groups.isNotEmpty) {
      rows.add(const SectionLabel('内容匹配'));
    }
    for (final g in out.groups) {
      rows.add(_groupHeader(context, g, p));
      for (final h in g.hits) {
        rows.add(_hitRow(context, g.path, h, p));
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: rows,
    );
  }

  Widget _nameRow(BuildContext context, String rel, Pal p) {
    final style = fileStyleFor(rel, p);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openHit(rel, 1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Row(
            children: [
              Icon(style.$1, size: 16, color: style.$2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(rel,
                    style: TextStyle(fontSize: 13, color: p.t1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.chevron_right, size: 16, color: p.t4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupHeader(BuildContext context, SearchGroup g, Pal p) {
    final style = fileStyleFor(g.path, p);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(style.$1, size: 15, color: style.$2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              g.path,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: p.t1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Pill(
            text: '${g.hits.length} 处',
            fg: p.t3,
            bg: p.dark ? p.hover : p.root,
            fontSize: 10.5,
          ),
        ],
      ),
    );
  }

  Widget _hitRow(BuildContext context, String rel, SearchHit h, Pal p) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openHit(rel, h.line),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 7, 16, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${h.line}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: p.t4,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  h.text.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: p.t2,
                    fontFamily: 'JetBrainsMono',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 14, color: accent.withValues(alpha: .7)),
            ],
          ),
        ),
      ),
    );
  }
}
