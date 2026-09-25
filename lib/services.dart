// PCV · 服务层（设置 / 项目 / 内置源码 / 搜索 / AI 客户端）
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

  // AI 双模式配置
  String aiMode = 'help'; // help | write
  String helpEndpoint = '';
  String helpApiKey = '';
  String helpModel = '';
  String writeEndpoint = '';
  String writeApiKey = '';
  String writeModel = '';
  bool aiAutoContext = true; // 自动附带最近打开文件作上下文

  Directory? _base;
  Directory get baseDir => _base!;

  bool get helpConfigured => helpEndpoint.isNotEmpty && helpModel.isNotEmpty;
  bool get writeConfigured => writeEndpoint.isNotEmpty && writeModel.isNotEmpty;

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
        aiMode = j['aiMode'] as String? ?? 'help';
        helpEndpoint = j['helpEndpoint'] as String? ?? '';
        helpApiKey = j['helpApiKey'] as String? ?? '';
        helpModel = j['helpModel'] as String? ?? '';
        writeEndpoint = j['writeEndpoint'] as String? ?? '';
        writeApiKey = j['writeApiKey'] as String? ?? '';
        writeModel = j['writeModel'] as String? ?? '';
        aiAutoContext = j['aiAutoContext'] as bool? ?? true;
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
          'aiMode': aiMode,
          'helpEndpoint': helpEndpoint,
          'helpApiKey': helpApiKey,
          'helpModel': helpModel,
          'writeEndpoint': writeEndpoint,
          'writeApiKey': writeApiKey,
          'writeModel': writeModel,
          'aiAutoContext': aiAutoContext,
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

  void setAiMode(String v) {
    aiMode = v;
    notifyListeners();
    save();
  }

  void setAiConfig({
    String? helpEndpoint,
    String? helpApiKey,
    String? helpModel,
    String? writeEndpoint,
    String? writeApiKey,
    String? writeModel,
    bool? aiAutoContext,
  }) {
    if (helpEndpoint != null) this.helpEndpoint = helpEndpoint.trim();
    if (helpApiKey != null) this.helpApiKey = helpApiKey.trim();
    if (helpModel != null) this.helpModel = helpModel.trim();
    if (writeEndpoint != null) this.writeEndpoint = writeEndpoint.trim();
    if (writeApiKey != null) this.writeApiKey = writeApiKey.trim();
    if (writeModel != null) this.writeModel = writeModel.trim();
    if (aiAutoContext != null) this.aiAutoContext = aiAutoContext;
    notifyListeners();
    save();
  }

  void clearRecent() {
    recent = [];
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

// ============ 项目模型 ============

class Project {
  Project({
    required this.id,
    required this.name,
    required this.path,
    this.builtin = false,
    this.version = '',
    this.commit = '',
    this.fileCount = 0,
  });

  final String id;
  String name;
  String path;
  final bool builtin;
  String version;
  String commit;
  int fileCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'builtin': builtin,
    'version': version,
    'commit': commit,
    'fileCount': fileCount,
  };

  static Project fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String,
    name: j['name'] as String? ?? '未命名',
    path: j['path'] as String,
    builtin: j['builtin'] as bool? ?? false,
    version: j['version'] as String? ?? '',
    commit: j['commit'] as String? ?? '',
    fileCount: (j['fileCount'] as num?)?.toInt() ?? 0,
  );
}

// ============ 项目服务（多项目：默认 LINGOS + 用户自建） ============

class ProjectsService extends ChangeNotifier {
  static final ProjectsService instance = ProjectsService._();
  ProjectsService._();

  static const _assetPath = 'assets/source/lingos-source-v0.7.2.pak.gz';

  final List<Project> projects = [];
  String currentId = 'lingos';
  bool loaded = false;
  bool unpacking = false;
  double progress = 0;
  String? error;

  Directory? _docs;
  Directory get docs => _docs ?? (throw StateError('未初始化'));

  Project? get current {
    for (final p in projects) {
      if (p.id == currentId) return p;
    }
    return projects.isEmpty ? null : projects.first;
  }

  Directory? get currentDir {
    final c = current;
    return c == null ? null : Directory(c.path);
  }

  Future<void> init() async {
    try {
      _docs = await getApplicationDocumentsDirectory();
      final pcvDir = Directory('${_docs!.path}/pcv');
      await pcvDir.create(recursive: true);

      // 1) 用户项目列表
      final projFile = File('${pcvDir.path}/projects.json');
      if (await projFile.exists()) {
        try {
          final list = (jsonDecode(await projFile.readAsString()) as List)
              .cast<Map<String, dynamic>>();
          for (final j in list) {
            final p = Project.fromJson(j);
            if (p.builtin) continue; // 内置项下方重建
            projects.add(p);
          }
        } catch (_) {}
      }

      // 2) 确保内置 LINGOS 项目（解压/校验）
      await _ensureBuiltin();

      loaded = true;
      notifyListeners();
    } catch (e) {
      error = '$e';
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> _ensureBuiltin({bool force = false}) async {
    final root = Directory('${_docs!.path}/pcv/projects/lingos');
    final metaFile = File('${root.path}/meta.json');

    if (!force && await metaFile.exists()) {
      try {
        final meta =
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        projects.removeWhere((p) => p.id == 'lingos');
        projects.insert(
          0,
          Project(
            id: 'lingos',
            name: 'LINGOS 源代码',
            path: root.path,
            builtin: true,
            version: meta['version'] as String? ?? '',
            commit: meta['commit'] as String? ?? '',
            fileCount: (meta['file_count'] as num?)?.toInt() ?? 0,
          ),
        );
        return;
      } catch (_) {}
    }

    // 需要解压
    unpacking = true;
    progress = 0;
    notifyListeners();

    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);

    final data = await rootBundle.load(_assetPath);
    final raw = gzip.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final magic = String.fromCharCodes(raw.sublist(0, 8));
    if (magic != 'PCVPAK1\n') {
      throw Exception('内置源码包格式不正确（magic 校验失败）');
    }
    final indexLen = int.parse(String.fromCharCodes(raw.sublist(8, 19)).trim());
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
      final f = File('${root.path}/$rel');
      await f.create(recursive: true);
      await f.writeAsBytes(
        raw.sublist(dataStart + o, dataStart + o + l),
        flush: false,
      );
      i++;
      if (i % 40 == 0 || i == files.length) {
        progress = i / files.length;
        notifyListeners();
      }
    }

    final meta = {
      'version': indexJson['version'] ?? '',
      'commit': indexJson['commit'] ?? '',
      'built_at': indexJson['built_at'] ?? '',
      'file_count': indexJson['file_count'] ?? files.length,
      'byte_count': indexJson['byte_count'] ?? 0,
    };
    await metaFile.writeAsString(jsonEncode(meta));

    projects.removeWhere((p) => p.id == 'lingos');
    projects.insert(
      0,
      Project(
        id: 'lingos',
        name: 'LINGOS 源代码',
        path: root.path,
        builtin: true,
        version: meta['version'] as String,
        commit: meta['commit'] as String,
        fileCount: (meta['file_count'] as num).toInt(),
      ),
    );

    unpacking = false;
    progress = 1;
    notifyListeners();
    await _saveProjects();
  }

  Future<void> restoreBuiltin() => _ensureBuiltin(force: true);

  Future<Project> createProject(String name) async {
    final safe = name.trim().isEmpty ? '未命名项目' : name.trim();
    final id = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final dir = Directory('${_docs!.path}/pcv/projects/$id');
    await dir.create(recursive: true);
    // 放一个欢迎文件
    await File('${dir.path}/README.md').writeAsString(
      '# $safe\n\n这是你在 PCV 中创建的项目。\n\n'
      '- 点击右下 `+` 新建文件/文件夹\n'
      '- 长按文件可重命名或删除\n',
    );
    final p = Project(id: id, name: safe, path: dir.path, fileCount: 1);
    projects.add(p);
    await _saveProjects();
    notifyListeners();
    return p;
  }

  Future<void> deleteProject(String id) async {
    final idx = projects.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final p = projects[idx];
    if (p.builtin) return; // 内置不可删
    try {
      final d = Directory(p.path);
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    projects.removeAt(idx);
    if (currentId == id) currentId = 'lingos';
    await _saveProjects();
    notifyListeners();
  }

  void switchTo(String id) {
    if (projects.any((p) => p.id == id)) {
      currentId = id;
      notifyListeners();
    }
  }

  Future<void> _saveProjects() async {
    try {
      final f = File('${_docs!.path}/pcv/projects.json');
      final userOnly = projects
          .where((p) => !p.builtin)
          .map((p) => p.toJson())
          .toList();
      await f.writeAsString(jsonEncode(userOnly));
    } catch (_) {}
  }

  Future<void> refreshFileCount() async {
    final c = current;
    if (c == null) return;
    try {
      var n = 0;
      await for (final e in Directory(
        c.path,
      ).list(recursive: true, followLinks: false)) {
        if (e is File) n++;
      }
      c.fileCount = n;
      notifyListeners();
    } catch (_) {}
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

// ============ AI 客户端（OpenAI 兼容——零第三方依赖） ============

class AiMessage {
  final String role; // system | user | assistant
  final String content;
  const AiMessage(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AiClient {
  /// 调用 OpenAI 兼容的 /chat/completions。
  /// [endpoint] 支持三种填法：base（https://host/v1）、完整 URL（…/chat/completions）、或带尾斜杠。
  static Future<String> chat({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<AiMessage> messages,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    var base = endpoint.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final url = base.endsWith('/chat/completions')
        ? base
        : '$base/chat/completions';

    final uri = Uri.parse(url);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      if (apiKey.isNotEmpty) {
        req.headers.set('Authorization', 'Bearer $apiKey');
      }
      req.add(
        utf8.encode(
          jsonEncode({
            'model': model,
            'messages': messages.map((m) => m.toJson()).toList(),
            'temperature': 0.3,
            'stream': false,
          }),
        ),
      );
      final resp = await req.close().timeout(timeout);
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${_short(body)}');
      }
      final j = jsonDecode(body) as Map<String, dynamic>;
      final choices = j['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('响应无 choices：${_short(body)}');
      }
      final msg = (choices.first as Map)['message'] as Map?;
      final content = (msg?['content'] ?? '').toString();
      if (content.isEmpty) throw Exception('响应内容为空：${_short(body)}');
      return content;
    } finally {
      client.close(force: true);
    }
  }

  static String _short(String s) =>
      s.length > 300 ? '${s.substring(0, 300)}…' : s;
}

/// 读取工作区文件内容（截断——AI 上下文预算）
Future<String> readFileForAi(
  Directory root,
  String rel, {
  int maxChars = 24000,
}) async {
  try {
    final f = File('${root.path}/$rel');
    if (!await f.exists()) return '（文件不存在：$rel）';
    var t = await f.readAsString();
    if (t.length > maxChars) {
      t = '${t.substring(0, maxChars)}\n…（已截断，原文件共 ${t.length} 字符）';
    }
    return t;
  } catch (e) {
    return '（读取失败：$e）';
  }
}

// ============ 格式化工具 ============

String fmtBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
}
