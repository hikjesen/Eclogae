import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:super_hot_key/super_hot_key.dart';
import 'package:window_manager/window_manager.dart';

import 'package:eclogae/base/audio_handler.dart';
import 'package:eclogae/base/yt_video_like_manager.dart';
import 'package:eclogae/class/route.dart';
import 'package:eclogae/class/shortcut_data.dart';
import 'package:eclogae/class/track.dart';
import 'package:eclogae/controller/bookmarks_controller.dart';
import 'package:eclogae/controller/chapters_controller.dart';
import 'package:eclogae/controller/indexer_controller.dart';
import 'package:eclogae/controller/logs_controller.dart';
import 'package:eclogae/controller/lyrics_controller.dart';
import 'package:eclogae/controller/miniplayer_controller.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/platform/base.dart';
import 'package:eclogae/controller/platform/window_manager/window_manager.dart';
import 'package:eclogae/controller/player_controller.dart';
import 'package:eclogae/controller/playlist_controller.dart';
import 'package:eclogae/controller/scroll_search_controller.dart';
import 'package:eclogae/controller/settings_controller.dart';
import 'package:eclogae/controller/tagger_controller.dart';
import 'package:eclogae/controller/window_controller.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/namida_converter_ext.dart';
import 'package:eclogae/core/translations/language.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/packages/mp.dart';
import 'package:eclogae/ui/pages/settings_page.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';
import 'package:eclogae/ui/widgets/settings_search_bar.dart';
import 'package:eclogae/youtube/class/youtube_id.dart';
import 'package:eclogae/youtube/controller/youtube_playlist_controller.dart';
import 'package:eclogae/youtube/widgets/yt_queue_chip.dart';

part 'shortcuts_manager_base.dart';
part 'shortcuts_manager_desktop.dart';
