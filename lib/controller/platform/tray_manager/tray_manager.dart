import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'package:dart_xdg_status_notifier_item/dart_xdg_status_notifier_item.dart';
import 'package:dbus/dbus.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:eclogae/controller/indexer_controller.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/platform/base.dart';
import 'package:eclogae/controller/player_controller.dart';
import 'package:eclogae/controller/tray_controller.dart';
import 'package:eclogae/controller/window_controller.dart';
import 'package:eclogae/core/constants.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/translations/language.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/main.dart';

part 'tray_manager_base.dart';
part 'tray_manager_desktop.dart';
part 'tray_manager_linux_dbus.dart';
