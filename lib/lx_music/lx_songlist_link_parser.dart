import 'lx_models.dart';

final _urlPattern = RegExp(r'https?://[A-Za-z0-9\-._~:/?#\[\]@!$&()*+,;=%]+');
final _trailingPunctuation = RegExp(r'''[.,;:!?)'"]+$''');
const _platformDomains = {
  LxPlatform.wy: ['163.com', '163cn.tv', '163cn.link'],
  LxPlatform.tx: ['y.qq.com'],
  LxPlatform.kg: ['kugou.com'],
  LxPlatform.kw: ['kuwo.cn'],
  LxPlatform.mg: ['migu.cn'],
};

({LxPlatform platform, String url})? parseSonglistLink(String input) {
  final match = _urlPattern.firstMatch(input)?.group(0);
  if (match == null) return null;

  final rawUrl = match.replaceFirst(_trailingPunctuation, '');
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return null;

  final host = uri.host.toLowerCase();
  for (final entry in _platformDomains.entries) {
    if (entry.value.any((domain) => host == domain || host.endsWith('.$domain'))) {
      return (platform: entry.key, url: rawUrl);
    }
  }
  return null;
}
