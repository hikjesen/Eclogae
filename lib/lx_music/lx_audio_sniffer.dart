import 'dart:io';
import 'dart:typed_data';

abstract final class LxAudioSniffer {
  static const audioExtensions = ['flac', 'mp3', 'm4a', 'ogg', 'wav', 'ape', 'aac', 'opus'];

  static Future<String> verifyAndDetectExtension(File file) async {
    final size = await file.exists() ? await file.length() : 0;
    if (size < 1024) throw FormatException('音频文件过小（$size 字节），可能下载不完整或被拦截');

    final handle = await file.open();
    final Uint8List head;
    try {
      head = await handle.read(32);
    } finally {
      await handle.close();
    }
    if (head.length < 12) throw const FormatException('音频文件头不完整');

    switch (String.fromCharCodes(head, 0, 4)) {
      case 'fLaC':
        return 'flac';
      case 'OggS':
        return 'ogg';
      case 'MAC ':
        return 'ape';
      case 'RIFF':
        return 'wav';
    }
    if (String.fromCharCodes(head, 0, 3) == 'ID3' || (head[0] == 0xff && (head[1] & 0xe0) == 0xe0)) return 'mp3';
    if (String.fromCharCodes(head, 4, 8) == 'ftyp') return 'm4a';
    throw const FormatException('无法识别音频文件头（服务端可能返回了 HTML 错误页或无效内容）');
  }

  static bool isValidImageBytes(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return true;
    if (bytes.length >= 4 && bytes[0] == 0x89 && String.fromCharCodes(bytes, 1, 4) == 'PNG') return true;
    return bytes.length >= 12 && String.fromCharCodes(bytes, 0, 4) == 'RIFF' && String.fromCharCodes(bytes, 8, 12) == 'WEBP';
  }
}
