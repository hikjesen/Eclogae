# Namida「在线曲库 & 悬浮歌词」项目交接文档（Stage 0 ~ Stage 6 完成）

> **更新时间**：2026-11-26
>
> **当前分支**：`main`（已合入 Stage 0 ~ Stage 6 全部提交，里程碑 Tag：`v8.6.7-lx-stage6`）
>
> **当前状态**：✅ **Stage 0 ~ Stage 6 全部功能、修复与真机验收均已通过并合并回 `main`** -> 下一阶段规划进入 **Stage 6.5（彻底脱离 Namida，独立品牌重塑为 `Eclogae`）**（须先由用户审阅变更清单后再动手）-> **Stage 7（五平台原生评论区适配）** -> 转为私有仓库。

---

## 1. 项目目标与工作区拓扑

- **项目目标**：基于当前已高度定制化的播放器底座，融合「在线曲库」（多平台聚合/分源歌曲与歌单搜索、关键词联想、第三方 `.js` 自定义音源本地/URL 导入、主播放器原生在线试听含封面/双语歌词/边播边缓/波形条/单曲循环、多音质并发下载校验、内嵌标签封面与完整 `.lrc` 导出、歌单子文件夹归档与外部歌单链接直达导入）及 **Android 原生轻量悬浮歌词**（自由定制配色/描边/RGB与图片吸管取色、翻译/罗马音独立开关、4 键浮层控制、Android 12+ 锁定穿透、媒体通知栏自定义按钮与防锁死静默解锁通知）。后续将在 Stage 6.5 独立演进为个人独立项目 **`Eclogae`**。
- **本地工作区**：
  - 主开发仓库：`d:\namida项目\namida`（当前分支 `main`，最新里程碑 Tag `v8.6.7-lx-stage6`，远端 `origin` = `https://github.com/hikjesen/namida.git`；Stage 6.5 完成后由用户手动改名为 `Eclogae` 并在 Stage 7 后转私有）
  - 只读参考仓库：`d:\namida项目\lx-music-mobile`（分支 `feature/android-download-mvp`，远端 `https://github.com/hikjesen/lx-music-mobile.git`）
- **开发与验收约束**：
  - 本机无 Flutter / Dart / Java 环境（仅安装有 `git`、`gh`、`node`、`npm`、`codex`），全程依赖 **GitHub Actions 免费构建**（`dart analyze` + ARM64 Release APK），用户下载 Artifact 到真机测试反馈。
  - **严禁提交任何第三方自定义音源 `.js` 文件、第三方音源链接、Cookie、私密 Token 或个人敏感凭据**。
  - **用户可见界面全面去 "LX" 化**：UI 统一使用「在线曲库」「在线曲库设置」「在线试听」「悬浮歌词」等命名；内部目录 `lib/lx_music/`、`lib/floating_lyrics/` 保持架构隔离。

---

## 2. 强制治理与协作规则（必读 `agent.md`）

请新会话的主控 Agent 开局先完整阅读 [`agent.md`](../agent.md) 与 [`AGENTS.md`](../AGENTS.md)，核心红线摘要如下：

1. **主控 Agent 统筹，Codex CLI 负责编码**：不要由主控 Agent 亲自写完所有代码，将编码任务拆解为边界清晰的子任务交给 Codex CLI（`gpt-6.2-sol`），主控负责架构、任务规格、Diff 审查与 CI 验收。
2. **绝对单向调用（严禁回调）**：绝对禁止 Codex 对主控 Agent（Antigravity / 反重力）进行任何形式的回调或反向触发。
3. **先核验再行动**：用户的根因猜测可能是错误的，任何修改前必须先通过源码、依赖或日志验证真实问题。
4. **严格约束 GPT 防御性编程**：下发 Codex 任务时必须显式禁止无意义判空、套娃 `try/catch`、静默吞错、冗余 fallback、过度抽象，并在回收 Diff 时逐行把关。
5. **额度耗尽必须停下来问用户**：如果 GPT / Codex 额度用尽或触发配额限制，**必须立即停止并询问用户**（换账号 / 切非官方模型 / 其他方案），**严禁擅自切换模型或通道**。
6. **禁止快速模式（Fast Mode）**：始终保持 `service_tier = "default"`；推理强度按任务复杂度在 `high` / `xhigh` / `max` 间灵活选用，**禁止使用过低档位（如 `low`）**。
7. **外部 PR Agent 约束**：仓库后续可能有其他 Agent 提交 PR，主控地位不变，外部 PR 须遵守 `agent.md` 与 `AGENTS.md`。

---

## 3. Codex CLI 已验证调用方式（Windows）

- **必须使用的二进制（重要）**：
  - 系统 `PATH` 中的旧版 `codex.exe`（`v0.153.4`）在 ChatGPT 认证下调用 `gpt-6.2-sol` 会返回 HTTP 400。
  - 必须显式调用 VS Code 扩展内置新版（`v0.171.0-alpha.13`）：
    ```
    C:\Users\HiKJeSen\.vscode\extensions\openai.chatgpt-26.1117.41037-win32-x64\bin\windows-x86_64\codex.exe
    ```
- **非交互调用模板**（非 TTY 下必须通过 stdin + 末尾 `-` 传参，避免挂起等待 stdin EOF）：
  ```powershell
  $codex = "C:\Users\HiKJeSen\.vscode\extensions\openai.chatgpt-26.1117.41037-win32-x64\bin\windows-x86_64\codex.exe"
  @'
  Read AGENTS.md and agent.md first. Strictly one-way execution; do NOT run git commit or git push.
  STRICT SCOPE: <明确文件/目录白名单>
  <清晰规格 + 反防御性编程约束>
  '@ | & $codex exec --ephemeral -m gpt-6.2-sol -c model_reasoning_effort=high -c service_tier=default -s workspace-write -C "d:\namida项目\namida" -
  ```
- **注意事项**：
  - 推理强度仅用 `high` / `xhigh` / `max`；显式保持 `service_tier=default`（严禁开启 `fast`）。
  - Windows PowerShell 5.1 不支持 `&&`，串行命令请使用 `; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }`。
  - 并行派发多个 Codex 任务时，务必保证每个任务的修改目录/文件集合严格互不重叠。
  - 本机 `gh` 已登录账号 `hikjesen`（具 `repo`、`workflow` 权限）；仅修改文档时请在 commit message 末尾加 `[skip ci]` 避免空耗 Android 构建。

---

## 4. 全阶段里程碑构建与真机验收记录

### 4.1 里程碑构建总表（全部全绿 + 真机验收通过）

| 阶段 | 分支 / Commit | CI Run | Artifact 大小 | 验收结论 |
| :--- | :--- | :--- | :--- | :--- |
| **Stage 0** | `feat/lx-stage0-ci` (`fd8c84bc`) | [45391810485](https://github.com/hikjesen/namida/actions/runs/45391810485) (`13m36s`) | `49,867,695 bytes` | ✅ Clean-Room 兼容包 + 共存包名 `com.msob7y.namida.lx` + 本地播放通过 |
| **Stage 1** | `feat/lx-stage1-bridge` (`c5b1dac2`) | [45412490417](https://github.com/hikjesen/namida/actions/runs/45412490417) (`13m24s`) | `50,634,615 bytes` | ✅ 固定签名生效 + Android 原生 QuickJS 双引擎 + 5 平台搜索/歌词/自定义源直链解析通过 |
| **Stage 2 (MVP)** | `feat/lx-stage2-download` (`e77de574`) | [45422922524](https://github.com/hikjesen/namida/actions/runs/45422922524) (`16m26s`) | `50,732,057 bytes` | ✅ 固定签名直接覆盖安装 + URL 在线导入 + 4 阶段下载/魔数校验/标签封面/完整 `.lrc`/即时入库通过 |
| **Stage 3 (美学重构)** | `feat/lx-stage3-polish` (`d3595ca5`) | [45566841964](https://github.com/hikjesen/namida/actions/runs/45566841964) (`15m+`) | ARM64 APK | ✅ Namida 原生美学重构、底栏 YouTube 替换为「在线曲库」、毛玻璃音质窗、记住上次音质、并发 1-3、防重检测、HEAD 进度探测 |
| **Stage 4 (在线试听与歌单)** | `feat/lx-stage3-polish` (`a2360084`) | [45606440084](https://github.com/hikjesen/namida/actions/runs/45606440084) (`15m+`) | ARM64 APK | ✅ 搜索状态持久化、聚合全源 + 关键词联想、主播放器原生在线试听/稍后播放、五平台歌单搜索网格与整单下载 |
| **真机反馈打磨 R2** | `feat/lx-stage3-polish` (`d968cf9f`) | [45617854104](https://github.com/hikjesen/namida/actions/runs/45617854104) (`15m+`) | ARM64 APK | ✅ 顶部精简为单行搜索栏、下载管理并入「在线曲库设置」双 Tab、右上角齿轮上下文切换、试听边播边缓存与波形条渲染通过 |
| **单曲循环根因修复 R3** | `feat/lx-stage3-polish` (`5f449d3d`) -> 已合并 `main` (`v8.6.7-lx-stage4`) | [45629267767](https://github.com/hikjesen/namida/actions/runs/45629267767) (`15m28s`) | `50,772,738 bytes` | ✅ 接入原生 `LoopMode.one` / `loop-file=inf` + 安全 EOF 重载兜底，本地与在线试听单曲循环真机全通过 |
| **Stage 5（歌单体验与缓存修复）** | `feat/lx-stage5-fixes` (`54613a3c`) -> 已合并 `main` (`v8.6.7-lx-stage5`) | [45757092704](https://github.com/hikjesen/namida/actions/runs/45757092704) (`17m35s`) | `50,781,361 bytes` | ✅ 歌单子文件夹归档、全目录递归防重、音频后缀对齐、封面缓存清理、大歌单自动分页下载、外部歌单链接搜索框直达导入真机验收通过 |
| **Stage 6（Android 原生悬浮歌词）** | `feat/lx-stage6-floating-lyrics` (`52faf3be`) | [45799484707](https://github.com/hikjesen/namida/actions/runs/45799484707) (`19m24s`) | `50,821,387 bytes` | ✅ 原生 Kotlin `TYPE_APPLICATION_OVERLAY` 悬浮窗、4 键浮层条、Android 12+ 锁定穿透、媒体通知栏自定义双按钮与静默解锁兜底初版通过 |
| **Stage 6 R2（横屏/省电/取色/双语拆分）** | `feat/lx-stage6-floating-lyrics` (`a0a82026`) -> 已合并 `main` (`v8.6.7-lx-stage6`) | [45808913273](https://github.com/hikjesen/namida/actions/runs/45808913273) (`15m22s`) | `50,836,243 bytes` | ✅ 横屏顶部全屏边界放开、隐身态保活消除系统通知频繁重弹、四重省电优化、8–34 sp / 2–8 行、翻译与罗马音独立开关、文字/描边 RGB 调色与图片吸管取色真机全通过 |

### 4.2 统一固定签名与 CI（已落地）
- 已在 `hikjesen/namida` 仓库配置 GitHub Actions Secrets：`LX_ANDROID_KEYSTORE_B64`、`LX_ANDROID_KEY_PROPERTIES_B64`（PKCS12 Keystore，本地私钥生成后已销毁、永不入库）。
- [.github/workflows/android-lx-build.yml](../.github/workflows/android-lx-build.yml) 自动解码写入 `android/app/keystore.jks` 与 `android/key.properties`（两者均在 `.gitignore` 中）；任意分支打出的 ARM64 Release APK **均可直接覆盖安装，保留本地设置与已导入音源**。

---

## 5. 已完成模块全景清单

### 5.1 闭源兼容包与播放引擎（`packages_compat/`）
- `packages_compat/basic_audio_handler`、`playlist_manager`、`youtipie`（离线空壳）、`namico_login_manager`、`namico_subscription_manager`、`flutter_sharing_intent`。
- **原生单曲循环与 EOF 重载修复**（`5f449d3d`）：
  - `packages_compat/basic_audio_handler/lib/src/av_player.dart`：`AVPlayer` 新增 `setLoopOne(bool enabled)`，`CustomAudioPlayer` 通过 `just_audio` 直接设置 `LoopMode.one`（Android `ExoPlayer.REPEAT_MODE_ONE`），并在 `setSource` 时自动重申状态。
  - `lib/class/custom_mpv_player.dart`：同步实现 `setLoopOne`（`_setMpvProperty('loop-file', enabled ? 'inf' : 'no')`）。
  - `packages_compat/basic_audio_handler/lib/src/handler.dart`：在 `PlayerRepeatMode.one`（以及单曲队列的 `PlayerRepeatMode.all`）且无按曲数睡眠定时 / 无自定义起止书签时自动启用原生单曲循环；需要从 `ProcessingState.completed` 重启的场景改为干净重载。

### 5.2 Android 原生双上下文 QuickJS 运行时与 SDK Bundle
- `android/app/src/main/kotlin/com/msob7y/namida/lx/`：
  - `LxCrypto.kt`、`LxUserApiRuntime.kt`、`LxMusicSdkRuntime.kt`、`LxQuickJsBridge.kt`（`MethodChannel("namida/lx_bridge")` + `EventChannel("namida/lx_events")`）。
  - R8 keep 规则位于 `android/app/proguard-rules.pro`（`com.whl.quickjs.**`、`com.msob7y.namida.lx.**`）。
- `tools/lx_music_sdk/` & `assets/lx/`：
  - `assets/lx/music-sdk-bundle.js`：导出 `kw`/`kg`/`tx`/`wy`/`mg` 五平台的 `musicSearch`、`tipSearch`、`songList`、`lyric`、`pic`，附 `smoke_test.mjs`。
  - `assets/lx/user-api-preload.js`：与 `lx-music-mobile` 协议逐字节一致。

### 5.3 Dart「在线曲库」业务层与原生风格 UI（全部收敛在 `lib/lx_music/`）
- **核心服务与状态**：`lx_models.dart`、`lx_http_proxy.dart`、`lx_user_api_store.dart`、`lx_bridge_service.dart`、`lx_audio_sniffer.dart`、`lx_download_resolver.dart`、`lx_download_manager.dart`、`lx_songlist_link_parser.dart`、`lx_search_controller.dart`、`lx_preview_player.dart`。
- **页面与组件**：`lx_music_page.dart`、`lx_songlist_detail_page.dart`、`lx_settings_page.dart`（双 Tab：`设置 | 下载管理`）、`lx_app_bar_icon.dart`、`widgets/*`。

### 5.4 Stage 6：Android 原生悬浮歌词系统（全部收敛在 `lib/floating_lyrics/` & `android/.../floatinglyrics/`）
- **Android 原生层**（`android/app/src/main/kotlin/com/msob7y/namida/floatinglyrics/`）：
  - `FloatingLyricsBridge.kt`：`MethodChannel("namida/floating_lyrics")` 挂载于 `NamidaAppChannels.configureEngine` 并在 `NamidaApplication.onCreate` 提前注册 `ActivityLifecycleCallbacks` 精准追踪前后台状态；向 Dart 回传拖动坐标、操作按钮事件、前后台切换与息屏/亮屏状态。
  - `FloatingLyricsManager.kt`：`TYPE_APPLICATION_OVERLAY` 悬浮窗管理、`fitInsetsTypes = 0` + `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS/SHORT_EDGES` 全屏真实边界（横屏顶部自由定位）、`suppressed` 1×1 透明不可触控保活态（避免切歌/切前后台反复拆建窗口导致系统通知频繁重弹）、Android 12+ 锁定穿透 `maximumObscuringOpacityForTouch <= 0.8f` 自动钳位、旋屏百分比复原。
  - `FloatingLyricsOverlayView.kt`：紧凑 4 键浮层控制条（播放/暂停、锁定、打开设置、关闭，3.5 秒自动收起）、自定义文字与描边色渲染（描边开启时关闭冗余模糊阴影）、多行 2–8 行 + 副行 0.8x/0.78 alpha、单行跑马灯（单次滚动至末尾停止、~30fps 节流、暂停/息屏/隐身即停）。
  - `FloatingLyricsLockNotification.kt` & `FloatingLyricsActionReceiver.kt`：当媒体通知栏未配置锁定键时锁窗自动弹出低优先级静默解锁通知（点击解锁 + 关闭按钮）。
  - 4 套原生 24dp 矢量图标：`floating_lyric_on.xml`、`floating_lyric_off.xml`、`floating_lyric_lock.xml`、`floating_lyric_unlock.xml`。
- **Dart 业务与设置页**（`lib/floating_lyrics/`）：
  - `floating_lyrics_models.dart` & `floating_lyrics_store.dart`：原子 JSON 持久化（`<appSupport>/floating_lyrics/settings.json`），支持 `8–34 sp` 字号、`2–8` 行、翻译/罗马音独立开关（兼容旧 `showSecondaryLine` 迁移）、自定义文字与描边 RGB 色值。
  - `floating_lyrics_channel.dart` & `floating_lyrics_controller.dart`：复用 `Lyrics.inst.currentLyricsLRC` + `lrc.forUiDisplay` + `Player.inst.nowPlayingPosition` + `CurrentColor.inst.miniplayerColorListenable`；结合 `Romanizer.inst.isRomanizationMatch` 精准分离翻译与罗马音；具备 200ms 行号零分配短路、息屏全面休眠、切歌解析期防抖与媒体锁键兜底联动。
  - `floating_lyrics_settings_page.dart` & `floating_lyrics_eyedropper_dialog.dart`：挂在「附加设置 → 歌词」下方的原生风格独立子页，支持实时预览、滑块拖动零高频写盘、文字与描边复用 `NamidaColorPickerDialog`（RGB/HSL/Hex + 当前专辑提取色板，取消自动复原）及专辑封面/本地图片像素吸管取色弹窗。

### 5.5 Namida 主干最小挂钩清单
- 在线曲库挂钩：`lib/core/namida_converter_ext.dart`、`lib/controller/scroll_search_controller.dart`、`lib/base/audio_handler.dart`、`lib/class/track.dart`、`lib/core/enums.dart`、`lib/controller/lyrics_controller.dart`、`lib/controller/indexer_controller.dart`、`lib/controller/indexer_artwork_extract_strategies.dart`、`lib/packages/miniplayer.dart`、`lib/ui/pages/settings_page.dart`、`lib/main_page_wrapper.dart`。
- 悬浮歌词挂钩：`android/app/src/main/AndroidManifest.xml`（`SYSTEM_ALERT_WINDOW` + `FloatingLyricsActionReceiver`）、`NamidaApplication.kt`、`NamidaAppChannels.kt`、`lib/main.dart`、`lib/controller/current_color.dart`、`lib/controller/lyrics_controller.dart`、`lib/controller/romanizer/romanizer.dart`、`lib/core/enums.dart`、`lib/core/namida_converter_ext.dart`、`lib/base/audio_handler.dart`、`lib/base/audio_handler.notification_buttons.dart`、`lib/ui/widgets/settings/extra_settings.dart`。

---

## 6. 关键已核验技术备忘（避免踩坑）

1. **Android ExoPlayer 单曲循环切勿在 `STATE_ENDED` 下硬 `seek(0)`**：常规单曲循环直接走 `AVPlayer.setLoopOne(true)`；确实需在 `STATE_ENDED` 后重播时必须重新加载音频源。
2. **在线试听音频波形与边播边缓**：复用 `http_cache_stream` 落盘到 `AppDirs.APP_CACHE/preview_audio/` 后，下载完成回调即可触发 `WaveformController.inst.generateWaveform(...)`。
3. **Dart 3.13 泛型推断**：Record 里返回空列表时必须显式写类型（如 `const <LxUserApiMeta>[]`）。
4. **`MSOB7YY/rhttp` 重定向与最终 URL**：上游 Rust `HttpResponse` 不回传重定向后最终 URL，已在 `LxHttpProxy` 配置 `RedirectSettings.none()` 并手工跟跳 3xx 后回传最终 `'url'`。
5. **Android 悬浮窗实测避坑（Stage 6 沉淀）**：
   - **Android 12+ 锁定穿透**：`FLAG_NOT_TOUCHABLE` 必须将 `layoutParams.alpha` 钳位至 `minOf(userAlpha, 0.8f, inputManager.maximumObscuringOpacityForTouch)`，否则系统反劫持策略会拦截下层点击。
   - **横屏顶部自由摆放**：API 30+ 必须设 `params.fitInsetsTypes = 0` + `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS` 并用 `maximumWindowMetrics.bounds` 全屏尺寸，否则系统会把窗口强推至状态栏/挖孔下方。
   - **避免 Android 系统「正在其他应用上层显示」频繁重弹**：开启悬浮歌词后，切歌解析或进前台隐身时切为 1×1 `alpha = 0f` + `FLAG_NOT_TOUCHABLE` 保活态而非 `removeView`/`addView`；仅在用户真正关闭悬浮歌词时移除窗口。
   - **悬浮窗省电四要素**：息屏广播同步 Dart 彻底停止推送、200ms 位置回调入口行号短路、单行跑马灯单次滚动 + ~30fps 节流（绝不用 `postOnAnimation` 锁死 120Hz）、描边时关闭冗余 `setShadowLayer` 模糊层。
6. **CI 监控**：代理环境下 `gh run watch` 偶发 `wsarecv` 断开，用 `gh run view --json status,conclusion,jobs` 轮询即可稳定跟踪。

---

## 7. 后续演进路线图（Stage 6.5 → Stage 7 → 私有化）

- [x] **Stage 0 ~ Stage 6 合并回 `main`**：已 fast-forward 合并并打 Tag `v8.6.7-lx-stage6`。
- [ ] **Stage 6.5（下一阶段）：彻底脱离 Namida，独立品牌重塑为 `Eclogae`**
  - 独立演进、不再跟踪上游 Namida 更新；
  - 修改全仓用户可见品牌名、翻译内置化、上游链接/更新检查剥离、包名与 CI 产物重命名（**具体深度档位先由用户审阅变更清单确认后再执行**）；
  - 代码清理与稳定构建完成后，由用户手动将 GitHub 仓库改名为 `Eclogae`（并清理旧同名仓库）。
- [ ] **Stage 7：五平台原生评论区适配**
  - 复用 `lx-music-mobile` 五平台 `comment.js` 经 `tools/lx_music_sdk/entry.js` 导出评论 RPC，并以原生毛玻璃面板呈现热门/最新评论与分页加载；
  - Stage 7 验收完成后，将仓库转为**私有仓库**长期个人维护。
- [ ] **其他按需增强**：Android 息屏大批量下载前台保活 Service、歌单广场 / 排行榜浏览。
