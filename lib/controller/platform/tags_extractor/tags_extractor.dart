import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:eclogae/class/faudiomodel.dart';
import 'package:eclogae/class/file_parts.dart';
import 'package:eclogae/class/taglib_res.dart';
import 'package:eclogae/class/track.dart';
import 'package:eclogae/controller/ffmpeg_controller.dart';
import 'package:eclogae/controller/logs_controller.dart';
import 'package:eclogae/controller/music_web_server/music_web_server_base.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/platform/ffmpeg_executer/ffmpeg_executer.dart';
import 'package:eclogae/controller/platform/namida_storage/namida_storage.dart';
import 'package:eclogae/controller/settings_controller.dart';
import 'package:eclogae/controller/thumbnail_manager.dart';
import 'package:eclogae/controller/video_controller.dart';
import 'package:eclogae/core/constants.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/namida_converter_ext.dart';
import 'package:eclogae/core/translations/language.dart';
import 'package:eclogae/youtube/class/download_task_base.dart';

part 'tags_extractor_android.dart';
part 'tags_extractor_base.dart';
part 'tags_extractor_desktop.dart';
part 'tags_extractor_taglib.dart';
