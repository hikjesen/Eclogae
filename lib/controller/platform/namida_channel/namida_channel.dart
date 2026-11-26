import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:dbus/dbus.dart';
import 'package:win32_registry/win32_registry.dart' as win32_registry;

import 'package:eclogae/controller/logs_controller.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/network_proxy_controller.dart';
import 'package:eclogae/controller/platform/namida_channel/windows_registry_watcher.dart';
import 'package:eclogae/controller/platform/base.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/ui/widgets/jellyfish.dart';

part 'namida_channel_android.dart';
part 'namida_channel_base.dart';
part 'namida_channel_darwin.dart';
part 'namida_channel_linux.dart';
part 'namida_channel_windows.dart';
