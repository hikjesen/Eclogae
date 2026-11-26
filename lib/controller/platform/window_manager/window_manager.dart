import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'package:eclogae/controller/platform/base.dart';
import 'package:eclogae/controller/platform/tray_manager/tray_manager.dart';
import 'package:eclogae/controller/screenshots_driver.dart';
import 'package:eclogae/controller/settings_controller.dart';
import 'package:eclogae/controller/window_controller.dart';
import 'package:eclogae/core/constants.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/main.dart';
import 'package:eclogae/ui/widgets/artwork.dart';

part 'window_manager_base.dart';
part 'window_manager_desktop.dart';
