// PCV · 服务层（设置 / 工作区 / 搜索）
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

// ============ 设置 ============

class SettingsModel extends ChangeNotifier {
  String themeMode = 'system'; // system | dark | light
  String accent = 'blue';
  double codeFontSize = 13;
  List<String> recent = [];

  Directory? _base;

  Directory get baseDir => _base!;

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    _base = Directory('${docs.path}/pcv');
    await _base!.create(recursive: true);
    final f = File('${_base!.path}/settings.json');
    if (await f.exists()) {
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        themeMode = j['themeMode'] as String? ?? 'system';
        accent = j['accent'] as String? ?? 'blue';
        codeFontSize = (j['codeFontSize'] as num?)?.toDouble() ?? 13;
        recent = (j['recent'] as List?)?.cast<String>() ?? [];
      } catch (_) {}
    }
  }

  Future<void> save() async {
    try {
      final f = File('${_base!.path}/settings.json');
      await f.writeAsString(
        jsonEncode({
          'themeMode': themeMode,
          'accent': accent,
          'codeFontSize': codeFontSize,
          'recent': recent,
        }),
      );
    } catch (_) {}
  }

  void setThemeMode(String v) {
    themeMode = v;
    notifyListeners();
    save();
  }

  void setAccent(String v) {
    accent = v;
    notifyListeners();
    save();
  }

  void setCodeFontSize(double v) {
    codeFontSize = v;
    notifyListeners();
    save();
  }

  void touchRecent(String path) {
    recent.remove(path);
    recent.insert(0, path);
    if (recent.length > 12) recent = recent.sublist(0, 12);
    notifyListeners();
    save();
  }
}

// ============ 工作区（内置源码解压） ============

enum WPhase { init, checking, unpacking, ready, error }

class WorkspaceService extends ChangeNotifier {
  static final WorkspaceService instance = WorkspaceService._();
  WorkspaceService._();

  WPhase phase = WPhase.init;
  double progress = 0;
  String? error;
  Directory? root;
  Directory? src;
  Map<String, dynamic> meta = {};

  static const _assetPath = 'assets/source/lingos-source-v0.7.2.pak.gz';

  Future<void> ensure({bool force = false}) async {
    try {
      phase = WPhase.checking;
      notifyListeners();

      final docs = await getApplicationDocumentsDirectory();
      root = Directory('${docs.path}/pcv/workspaces/lingos');
      src = Directory('${root!.path}/src');
      final metaFile = File('${root!.path}/meta.json');

      if (!force && await metaFile.exists() && await src!.exists()) {
        try {
          meta =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          phase = WPhase.ready;
          notifyListeners();
          return;
        } catch (_) {}
      }

      phase = WPhase.unpacking;
      progress = 0;
      notifyListeners();

      if (await root!.exists()) {
        await root!.delete(recursive: true);
      }
      await src!.create(recursive: true);

      final data = await rootBundle.load(_assetPath);
      final raw = gzip.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final magic = String.fromCharCodes(raw.sublist(0, 8));
      if (magic != 'PCVPAK1\n') {
        throw Exception('内置源码包格式不正确（magic 校验失败）');
      }
      final indexLen = int.parse(
        String.fromCharCodes(raw.sublist(8, 19)).trim(),
      );
      final indexJson = jsonDecode(
        utf8.decode(raw.sublist(19, 19 + indexLen)),
      ) as Map<String, dynamic>;
      final dataStart = 19 + indexLen;
      final files = (indexJson['files'] as List).cast<Map<String, dynamic>>();

      var i = 0;
      for (final ent in files) {
        final rel = ent['p'] as String;
        final o = ent['o'] as int;
        final l = ent['l'] as int;
        final f = File('${src!.path}/$rel');
        await f.create(recursive: true);
        await f.writeAsBytes(
          raw.sublist(dataStart + o, dataStart + o + l),
          flush: false,
        );
        i++;
        if (i % 25 == 0 || i == files.length) {
          progress = i / files.length;
          notifyListeners();
        }
      }

      meta = {
        'version': indexJson['version'] ?? '',
        'commit': indexJson['commit'] ?? '',
        'built_at': indexJson['built_at'] ?? '',
        'file_count': indexJson['file_count'] ?? files.length,
        'byte_count': indexJson['byte_count'] ?? 0,
      };
      await metaFile.writeAsString(jsonEncode(meta));
      progress = 1;
      phase = WPhase.ready;
      notifyListeners();
    } catch (e) {
      error = '$e';
      phase = WPhase.error;
      notifyListeners();
    }
  }
}

// ============ 搜索 ============

class SearchHit {
  final int line;
  final String text;
  const SearchHit(this.line, this.text);
}

class SearchGroup {
  final String path;
  final List<SearchHit> hits;
  SearchGroup(this.path, this.hits);
}

class SearchOutcome {
  final List<SearchGroup> groups;
  final List<String> nameHits;
  final int total;
  final bool truncated;
  const SearchOutcome(this.groups, this.nameHits, this.total, this.truncated);
}

const _skipExts = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.ico',
  '.webp',
  '.so',
  '.a',
  '.o',
  '.bin',
  '.gz',
  '.zip',
  '.jks',
  '.ttf',
  '.woff',
  '.woff2',
  '.pak',
  '.mp3',
  '.mp4',
  '.wav',
  '.jar',
  '.exe',
  '.dll',
  '.class',
  '.pyc',
};

bool _looksBinary(List<int> bytes) {
  final n = bytes.length < 8000 ? bytes.length : 8000;
  for (var i = 0; i < n; i++) {
    if (bytes[i] == 0) return true;
  }
  return false;
}

Future<SearchOutcome> searchWorkspace(
  Directory src,
  String query, {
  bool nameOnly = false,
  bool contentOnly = false,
  int maxHits = 400,
}) async {
  final q = query.trim();
  if (q.isEmpty) {
    return const SearchOutcome([], [], 0, false);
  }
  final ql = q.toLowerCase();
  final nameHits = <String>[];
  final groups = <SearchGroup>[];
  var total = 0;
  var truncated = false;

  List<FileSystemEntity> entities;
  try {
    entities = src.listSync(recursive: true, followLinks: false);
  } catch (_) {
    entities = [];
  }

  final files = <File>[];
  for (final e in entities) {
    if (e is File) files.add(e);
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    final rel = f.path.substring(src.path.length + 1);
    final dot = rel.lastIndexOf('.');
    final ext = dot >= 0 ? rel.substring(dot).toLowerCase() : '';
    if (_skipExts.contains(ext)) continue;

    if (!contentOnly && rel.toLowerCase().contains(ql)) {
      nameHits.add(rel);
      if (nameHits.length > 100) {
        truncated = true;
      }
    }
    if (nameOnly) continue;
    if (truncated && total >= maxHits) continue;

    try {
      final len = await f.length();
      if (len > 512 * 1024) continue;
      final bytes = await f.readAsBytes();
      if (_looksBinary(bytes)) continue;
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!text.toLowerCase().contains(ql)) continue;

      final lines = text.split('\n');
      final hits = <SearchHit>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains(ql)) {
          var t = lines[i].trimRight();
          if (t.length > 200) {
            final idx = t.toLowerCase().indexOf(ql);
            final start = idx > 60 ? idx - 60 : 0;
            t = '…${t.substring(start)}';
            if (t.length > 200) t = '${t.substring(0, 200)}…';
          }
          hits.add(SearchHit(i + 1, t));
          total++;
          if (total >= maxHits) {
            truncated = true;
            break;
          }
        }
      }
      if (hits.isNotEmpty) {
        groups.add(SearchGroup(rel, hits));
      }
      if (truncated && total >= maxHits) break;
    } catch (_) {}
  }

  return SearchOutcome(groups, nameHits, total, truncated);
}

// ============ 格式化工具 ============

String fmtBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
}
