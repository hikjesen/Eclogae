import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show mapEquals, visibleForTesting;
import 'package:flutter/services.dart';

import 'package:file_picker/file_picker.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;
import 'package:sqlite3/sqlite3.dart';

import 'package:eclogae/class/file_parts.dart';
import 'package:eclogae/controller/directory_index.dart';
import 'package:eclogae/controller/logs_controller.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/platform/base.dart';
import 'package:eclogae/controller/playlist_controller.dart';
import 'package:eclogae/controller/settings_controller.dart';
import 'package:eclogae/core/constants.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/translations/language.dart';

part 'namida_storage_android.dart';
part 'namida_storage_base.dart';
part 'namida_storage_darwin.dart';
part 'namida_storage_paths_migrator.dart';
part 'namida_storage_windows.dart';
part 'namida_storage_linux.dart';
