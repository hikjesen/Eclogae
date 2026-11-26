import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'floating_lyrics_models.dart';

class FloatingLyricsStore {
  static const _fileName = 'settings.json';

  late final _root = getApplicationSupportDirectory().then((dir) => Directory(p.join(dir.path, 'floating_lyrics')));
  Future<void> _writeTail = Future<void>.value();

  Future<FloatingLyricsSettings> load() async {
    final file = File(p.join((await _root).path, _fileName));
    if (!await file.exists()) return const FloatingLyricsSettings();
    return FloatingLyricsSettings.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  }

  Future<void> save(FloatingLyricsSettings settings) async {
    final previousWrite = _writeTail;
    final finished = Completer<void>();
    _writeTail = finished.future;
    await previousWrite;
    try {
      await _write(settings);
    } finally {
      finished.complete();
    }
  }

  Future<void> _write(FloatingLyricsSettings settings) async {
    final root = await _root;
    await root.create(recursive: true);
    final staging = File(p.join(root.path, '$_fileName.${const Uuid().v4()}.tmp'));
    try {
      await staging.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await staging.rename(p.join(root.path, _fileName));
    } on FileSystemException {
      if (await staging.exists()) await staging.delete();
      rethrow;
    }
  }
}
