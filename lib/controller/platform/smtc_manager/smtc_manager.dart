import 'dart:async';

import 'package:flutter/material.dart';

import 'package:anni_mpris_service/anni_mpris_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dbus/dbus.dart';
import 'package:smtc_windows/smtc_windows.dart' as swin;
import 'package:youtipie/core/url_utils.dart';

import 'package:eclogae/class/track.dart';
import 'package:eclogae/controller/logs_controller.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/now_playing_broadcaster.dart';
import 'package:eclogae/controller/platform/base.dart';
import 'package:eclogae/controller/platform/tray_manager/tray_manager.dart';
import 'package:eclogae/controller/platform/window_manager/window_manager.dart';
import 'package:eclogae/controller/player_controller.dart';
import 'package:eclogae/controller/settings_controller.dart';
import 'package:eclogae/core/constants.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/namida_converter_ext.dart';
import 'package:eclogae/core/translations/language.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/main.dart';

part 'smtc_manager_base.dart';
part 'smtc_manager_linux.dart';
part 'smtc_manager_windows.dart';
