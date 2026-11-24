import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'lx_models.dart';

class LxUserApiStore {
  static final _headerPattern = RegExp(r'^/\*[\s\S]+?\*/');
  static final _fieldPattern = RegExp(r'^\s?\*\s?@(\w+)\s(.+)$');
  static final _idPattern = RegExp(r'^user_api_[a-f0-9-]+$');
  static const _fieldLengths = {'name': 24, 'description': 36, 'author': 56, 'homepage': 1024, 'version': 36};

  late final Future<Directory> _root = getApplicationSupportDirectory().then((dir) => Directory(p.join(dir.path, 'lx_music')));

  Future<({List<LxUserApiMeta> scripts, String? activeId})> loadAll() async {
    final manifest = File(p.join((await _root).path, 'manifest.json'));
    if (!await manifest.exists()) return (scripts: const <LxUserApiMeta>[], activeId: null);
    final json = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    return (
      scripts: (json['scripts'] as List<dynamic>).map((data) => LxUserApiMeta.fromJson(data as Map<String, dynamic>)).toList(),
      activeId: json['activeId'] as String?,
    );
  }

  Future<LxUserApiMeta> importFromFile(File file) async {
    final fileName = p.basename(file.path);
    if (p.extension(fileName).toLowerCase() != '.js') throw const FormatException('请选择 .js 音源文件');
    final raw = await file.readAsString();
    final script = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    final header = _headerPattern.stringMatch(script);
    if (header == null) throw const FormatException('文件开头缺少 LX 音源注释');

    final fields = <String, String>{};
    for (final line in const LineSplitter().convert(header)) {
      final field = _fieldPattern.firstMatch(line);
      if (field == null) continue;
      final key = field[1]!;
      final limit = _fieldLengths[key];
      if (limit == null) continue;
      final value = field[2]!.trim();
      fields[key] = value.length > limit ? '${value.substring(0, limit)}...' : value;
    }

    final now = DateTime.now();
    final name = fields['name'] ?? '';
    final meta = LxUserApiMeta(
      id: 'user_api_${const Uuid().v4()}',
      name: name.isEmpty ? 'user_api_$now' : name,
      description: fields['description'] ?? '',
      version: fields['version'] ?? '',
      author: fields['author'] ?? '',
      homepage: fields['homepage'] ?? '',
      fileName: fileName,
      importedAt: now,
    );
    final saved = await loadAll();
    final target = await _scriptFile(meta.id);
    await target.parent.create(recursive: true);
    await target.writeAsString(script, flush: true);
    await _writeManifest([...saved.scripts, meta], saved.activeId);
    return meta;
  }

  Future<String> readScript(LxUserApiMeta meta) async => (await _scriptFile(meta.id)).readAsString();

  Future<void> setActiveId(String? id) async {
    final saved = await loadAll();
    await _writeManifest(saved.scripts, id);
  }

  Future<void> remove(String id) async {
    final saved = await loadAll();
    final scripts = saved.scripts.where((script) => script.id != id).toList();
    final target = await _scriptFile(id);
    await _writeManifest(scripts, saved.activeId == id ? null : saved.activeId);
    if (await target.exists()) await target.delete();
  }

  Future<File> _scriptFile(String id) async {
    if (!_idPattern.hasMatch(id)) throw const FormatException('音源 ID 无效');
    return File(p.join((await _root).path, 'sources', '$id.js'));
  }

  Future<void> _writeManifest(List<LxUserApiMeta> scripts, String? activeId) async {
    final root = await _root;
    await root.create(recursive: true);
    final staging = File(p.join(root.path, 'manifest.json.tmp'));
    await staging.writeAsString(jsonEncode({'scripts': scripts, 'activeId': activeId}), flush: true);
    await staging.rename(p.join(root.path, 'manifest.json'));
  }
}
