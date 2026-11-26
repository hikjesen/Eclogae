// ignore: depend_on_referenced_packages
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'package:eclogae/controller/platform/base.dart';
import 'package:eclogae/controller/platform/tray_manager/tray_manager.dart';
import 'package:eclogae/core/constants.dart';
import 'package:eclogae/main.dart';

part 'app_single_instance_base.dart';
part 'app_single_instance_linux.dart';
part 'app_single_instance_windows.dart';
