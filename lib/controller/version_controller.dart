import 'package:eclogae/class/version_wrapper.dart';
import 'package:eclogae/core/utils.dart';

class VersionController {
  static final inst = VersionController._();
  VersionController._();

  RxBaseCore<VersionWrapper?> get latestVersion => _latestVersion;
  RxBaseCore<List<VersionReleaseInfo>?> get releasesAfterCurrent => _releasesAfterCurrent;

  final _latestVersion = Rxn<VersionWrapper>();
  final _releasesAfterCurrent = Rxn<List<VersionReleaseInfo>>(const <VersionReleaseInfo>[]);

  void ensureInitialized() {}

  void ensureRefreshed() {}

  Future<List<VersionReleaseInfo>?> fetchReleasesAfterCurrent() => Future.value(const <VersionReleaseInfo>[]);
}

class VersionReleaseInfo {
  final VersionWrapper version;
  final String body;

  const VersionReleaseInfo({
    required this.version,
    required this.body,
  });

  @override
  String toString() => 'VersionReleaseInfo(name: $version, body: $body)';
}
